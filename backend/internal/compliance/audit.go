package compliance

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type AuditService struct {
	pool *pgxpool.Pool
}

func NewAuditService(pool *pgxpool.Pool) *AuditService {
	return &AuditService{pool: pool}
}

type AuditEntry struct {
	ID         uuid.UUID       `json:"id"`
	OrgID      uuid.UUID       `json:"org_id"`
	UserID     *uuid.UUID      `json:"user_id,omitempty"`
	Action     string          `json:"action"`
	EntityType string          `json:"entity_type"`
	EntityID   *uuid.UUID      `json:"entity_id,omitempty"`
	IPAddress  string          `json:"ip_address,omitempty"`
	PayloadHash string         `json:"payload_hash,omitempty"`
	Metadata   json.RawMessage `json:"metadata,omitempty"`
	CreatedAt  string          `json:"created_at"`
}

func (s *AuditService) Log(ctx context.Context, orgID uuid.UUID, userID *uuid.UUID, action, entityType string, entityID *uuid.UUID, ip string, metadata any) error {
	var payloadHash *string
	if metadata != nil {
		b, _ := json.Marshal(metadata)
		h := sha256.Sum256(b)
		hash := hex.EncodeToString(h[:])
		payloadHash = &hash
	}
	var metaJSON []byte
	if metadata != nil {
		metaJSON, _ = json.Marshal(metadata)
	}
	var ipAddr *net.IP
	if ip != "" {
		parsed := net.ParseIP(ip)
		if parsed != nil {
			ipAddr = &parsed
		}
	}
	_, err := s.pool.Exec(ctx, `
		INSERT INTO audit_log (org_id, user_id, action, entity_type, entity_id, ip_address, payload_hash, metadata)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		orgID, userID, action, entityType, entityID, ipAddr, payloadHash, metaJSON,
	)
	return err
}

func (s *AuditService) List(ctx context.Context, orgID uuid.UUID, from, to string, limit int) ([]AuditEntry, error) {
	if limit <= 0 || limit > 1000 {
		limit = 100
	}
	rows, err := s.pool.Query(ctx, `
		SELECT id, org_id, user_id, action, entity_type, entity_id,
			COALESCE(host(ip_address), ''), COALESCE(payload_hash, ''), metadata,
			created_at::text
		FROM audit_log
		WHERE org_id = $1 AND created_at >= $2::timestamptz AND created_at <= $3::timestamptz
		ORDER BY created_at DESC LIMIT $4`,
		orgID, from, to, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AuditEntry
	for rows.Next() {
		var e AuditEntry
		var meta []byte
		if err := rows.Scan(&e.ID, &e.OrgID, &e.UserID, &e.Action, &e.EntityType, &e.EntityID, &e.IPAddress, &e.PayloadHash, &meta, &e.CreatedAt); err != nil {
			return nil, err
		}
		if len(meta) > 0 {
			e.Metadata = meta
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
