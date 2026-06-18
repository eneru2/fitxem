package billing

import (
	"context"
	"encoding/json"
	"io"
	"net/http"

	"github.com/eneru2/just-clock/internal/org"
)

type Service struct {
	secretKey string
	orgSvc    *org.Service
}

func NewService(secretKey string, orgSvc *org.Service) *Service {
	return &Service{secretKey: secretKey, orgSvc: orgSvc}
}

type CheckoutRequest struct {
	OrgID       string `json:"org_id"`
	Email       string `json:"email"`
	SeatCount   int    `json:"seat_count"`
	SuccessURL  string `json:"success_url"`
	CancelURL   string `json:"cancel_url"`
}

// HandleWebhook processes Stripe events when configured.
func (s *Service) HandleWebhook(w http.ResponseWriter, r *http.Request) {
	if s.secretKey == "" {
		http.Error(w, "billing not configured", http.StatusNotImplemented)
		return
	}
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "read body", http.StatusBadRequest)
		return
	}
	var evt stripeEvent
	if err := json.Unmarshal(body, &evt); err != nil {
		http.Error(w, "invalid payload", http.StatusBadRequest)
		return
	}
	switch evt.Type {
	case "customer.subscription.updated", "customer.subscription.created":
		if err := s.handleSubscription(r.Context(), evt); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}
	w.WriteHeader(http.StatusOK)
}

type stripeEvent struct {
	Type string `json:"type"`
	Data struct {
		Object struct {
			Customer string `json:"customer"`
			Status   string `json:"status"`
		} `json:"object"`
	} `json:"data"`
}

func (s *Service) handleSubscription(ctx context.Context, evt stripeEvent) error {
	customerID := evt.Data.Object.Customer
	tier := "active"
	if evt.Data.Object.Status != "active" {
		tier = "inactive"
	}
	o, err := s.orgSvc.GetByStripeCustomer(ctx, customerID)
	if err != nil {
		return nil
	}
	return s.orgSvc.UpdateSubscription(ctx, o.ID, tier, customerID)
}

func (s *Service) CreateCheckoutSession(w http.ResponseWriter, r *http.Request) {
	if s.secretKey == "" {
		http.Error(w, `{"error":"billing not configured — set STRIPE_SECRET_KEY"}`, http.StatusNotImplemented)
		return
	}
	// Stripe SDK integration point; returns placeholder until keys configured
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{
		"message": "Configure STRIPE_SECRET_KEY to enable checkout",
	})
}
