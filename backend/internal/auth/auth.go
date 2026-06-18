package auth

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrUnauthorized       = errors.New("unauthorized")
)

type Claims struct {
	UserID   string `json:"user_id"`
	OrgID    string `json:"org_id"`
	Email    string `json:"email"`
	Role     string `json:"role"`
	TokenType string `json:"token_type"`
	jwt.RegisteredClaims
}

type Service struct {
	pool       *pgxpool.Pool
	jwtSecret  []byte
	accessTTL  time.Duration
	refreshTTL time.Duration
}

func NewService(pool *pgxpool.Pool, jwtSecret string, accessTTL, refreshTTL time.Duration) *Service {
	return &Service{
		pool:       pool,
		jwtSecret:  []byte(jwtSecret),
		accessTTL:  accessTTL,
		refreshTTL: refreshTTL,
	}
}

type User struct {
	ID       uuid.UUID
	OrgID    uuid.UUID
	Email    string
	Role     string
	Password string
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	ExpiresIn    int64  `json:"expires_in"`
}

type RegisterOrgInput struct {
	CIF          string
	LegalName    string
	OwnerEmail   string
	OwnerPassword string
	OwnerName    string
	OwnerNIF     string
}

type RegisterOrgResult struct {
	OrgID        uuid.UUID `json:"org_id"`
	UserID       uuid.UUID `json:"user_id"`
	EmployeeID   uuid.UUID `json:"employee_id"`
	AccessToken  string    `json:"access_token"`
	RefreshToken string    `json:"refresh_token"`
}

func (s *Service) RegisterOrg(ctx context.Context, in RegisterOrgInput) (*RegisterOrgResult, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(in.OwnerPassword), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	var orgID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO organizations (cif, legal_name) VALUES ($1, $2) RETURNING id`,
		in.CIF, in.LegalName,
	).Scan(&orgID)
	if err != nil {
		return nil, fmt.Errorf("create org: %w", err)
	}

	var centerID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO work_centers (org_id, name) VALUES ($1, $2) RETURNING id`,
		orgID, "Principal",
	).Scan(&centerID)
	if err != nil {
		return nil, err
	}

	var userID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO users (org_id, email, password_hash, role) VALUES ($1, $2, $3, 'owner') RETURNING id`,
		orgID, in.OwnerEmail, string(hash),
	).Scan(&userID)
	if err != nil {
		return nil, err
	}

	var employeeID uuid.UUID
	err = tx.QueryRow(ctx,
		`INSERT INTO employees (org_id, user_id, work_center_id, nif, full_name) VALUES ($1, $2, $3, $4, $5) RETURNING id`,
		orgID, userID, centerID, in.OwnerNIF, in.OwnerName,
	).Scan(&employeeID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}

	tokens, err := s.issueTokens(ctx, userID, orgID, in.OwnerEmail, "owner")
	if err != nil {
		return nil, err
	}

	return &RegisterOrgResult{
		OrgID:        orgID,
		UserID:       userID,
		EmployeeID:   employeeID,
		AccessToken:  tokens.AccessToken,
		RefreshToken: tokens.RefreshToken,
	}, nil
}

func (s *Service) Login(ctx context.Context, email, password string) (*TokenPair, *User, error) {
	var u User
	err := s.pool.QueryRow(ctx,
		`SELECT id, org_id, email, password_hash, role::text FROM users WHERE email = $1`,
		email,
	).Scan(&u.ID, &u.OrgID, &u.Email, &u.Password, &u.Role)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil, ErrInvalidCredentials
		}
		return nil, nil, err
	}

	if err := bcrypt.CompareHashAndPassword([]byte(u.Password), []byte(password)); err != nil {
		return nil, nil, ErrInvalidCredentials
	}

	tokens, err := s.issueTokens(ctx, u.ID, u.OrgID, u.Email, u.Role)
	if err != nil {
		return nil, nil, err
	}
	return tokens, &u, nil
}

func (s *Service) Refresh(ctx context.Context, refreshToken string) (*TokenPair, error) {
	hash := hashToken(refreshToken)
	var userID, orgID uuid.UUID
	var email, role string
	var expiresAt time.Time
	err := s.pool.QueryRow(ctx, `
		SELECT rt.expires_at, u.id, u.org_id, u.email, u.role::text
		FROM refresh_tokens rt
		JOIN users u ON u.id = rt.user_id
		WHERE rt.token_hash = $1`,
		hash,
	).Scan(&expiresAt, &userID, &orgID, &email, &role)
	if err != nil {
		return nil, ErrUnauthorized
	}
	if time.Now().After(expiresAt) {
		return nil, ErrUnauthorized
	}
	return s.issueTokens(ctx, userID, orgID, email, role)
}

func (s *Service) ParseAccessToken(tokenStr string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		return s.jwtSecret, nil
	})
	if err != nil || !token.Valid {
		return nil, ErrUnauthorized
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || claims.TokenType != "access" {
		return nil, ErrUnauthorized
	}
	return claims, nil
}

func (s *Service) issueTokens(ctx context.Context, userID, orgID uuid.UUID, email, role string) (*TokenPair, error) {
	now := time.Now()
	accessClaims := &Claims{
		UserID:    userID.String(),
		OrgID:     orgID.String(),
		Email:     email,
		Role:      role,
		TokenType: "access",
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(now.Add(s.accessTTL)),
			IssuedAt:  jwt.NewNumericDate(now),
			Subject:   userID.String(),
		},
	}
	accessToken, err := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims).SignedString(s.jwtSecret)
	if err != nil {
		return nil, err
	}

	refreshRaw, err := randomToken()
	if err != nil {
		return nil, err
	}
	refreshHash := hashToken(refreshRaw)
	_, err = s.pool.Exec(ctx,
		`INSERT INTO refresh_tokens (user_id, token_hash, expires_at) VALUES ($1, $2, $3)`,
		userID, refreshHash, now.Add(s.refreshTTL),
	)
	if err != nil {
		return nil, err
	}

	return &TokenPair{
		AccessToken:  accessToken,
		RefreshToken: refreshRaw,
		ExpiresIn:    int64(s.accessTTL.Seconds()),
	}, nil
}

func randomToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func hashToken(token string) string {
	h := sha256.Sum256([]byte(token))
	return hex.EncodeToString(h[:])
}
