package compliance

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"time"

	"github.com/eneru2/just-clock/internal/clock"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/jung-kurt/gofpdf"
)

type ExportService struct {
	pool *pgxpool.Pool
	clock *clock.Service
}

func NewExportService(pool *pgxpool.Pool, clockSvc *clock.Service) *ExportService {
	return &ExportService{pool: pool, clock: clockSvc}
}

type ExportRequest struct {
	OrgID uuid.UUID
	From  time.Time
	To    time.Time
	CIF   string
}

type JSONExport struct {
	CompanyCIF string                      `json:"company_cif"`
	From       time.Time                   `json:"from"`
	To         time.Time                   `json:"to"`
	ExportedAt time.Time                   `json:"exported_at"`
	Records    []clock.ClockEventWithEmployee `json:"records"`
	ExportHash string                      `json:"export_hash"`
}

func (s *ExportService) ExportJSON(ctx context.Context, req ExportRequest) ([]byte, error) {
	records, err := s.clock.ListOrgRecords(ctx, req.OrgID, req.From, req.To)
	if err != nil {
		return nil, err
	}
	exp := JSONExport{
		CompanyCIF: req.CIF,
		From:       req.From,
		To:         req.To,
		ExportedAt: time.Now().UTC(),
		Records:    records,
	}
	b, err := json.Marshal(exp)
	if err != nil {
		return nil, err
	}
	h := sha256.Sum256(b)
	exp.ExportHash = hex.EncodeToString(h[:])
	return json.MarshalIndent(exp, "", "  ")
}

type XMLRecord struct {
	EmployeeNIF  string    `xml:"EmployeeNIF"`
	EmployeeName string    `xml:"EmployeeName"`
	EventType    string    `xml:"EventType"`
	RecordedAt   time.Time `xml:"RecordedAt"`
	HourType     string    `xml:"HourType"`
	WorkCenter   string    `xml:"WorkCenter,omitempty"`
	EventHash    string    `xml:"EventHash"`
	IsCorrection bool      `xml:"IsCorrection"`
}

type XMLExport struct {
	XMLName    xml.Name    `xml:"JustClockExport"`
	CompanyCIF string      `xml:"CompanyCIF"`
	From       time.Time   `xml:"From"`
	To         time.Time   `xml:"To"`
	ExportedAt time.Time   `xml:"ExportedAt"`
	Records    []XMLRecord `xml:"Records>Record"`
}

func (s *ExportService) ExportXML(ctx context.Context, req ExportRequest) ([]byte, error) {
	records, err := s.clock.ListOrgRecords(ctx, req.OrgID, req.From, req.To)
	if err != nil {
		return nil, err
	}
	xr := XMLExport{
		CompanyCIF:   req.CIF,
		From:       req.From,
		To:         req.To,
		ExportedAt: time.Now().UTC(),
	}
	for _, r := range records {
		xr.Records = append(xr.Records, XMLRecord{
			EmployeeNIF:  r.EmployeeNIF,
			EmployeeName: r.EmployeeName,
			EventType:    string(r.EventType),
			RecordedAt:   r.RecordedAt,
			HourType:     r.HourType,
			WorkCenter:   r.WorkCenterName,
			EventHash:    r.EventHash,
			IsCorrection: r.IsCorrection,
		})
	}
	return xml.MarshalIndent(xr, "", "  ")
}

func (s *ExportService) ExportPDF(ctx context.Context, req ExportRequest) ([]byte, error) {
	records, err := s.clock.ListOrgRecords(ctx, req.OrgID, req.From, req.To)
	if err != nil {
		return nil, err
	}

	pdf := gofpdf.New("P", "mm", "A4", "")
	pdf.AddPage()
	pdf.SetFont("Arial", "B", 16)
	pdf.Cell(0, 10, "Just Clock - Informe de fichaje")
	pdf.Ln(12)
	pdf.SetFont("Arial", "", 11)
	pdf.Cell(0, 8, fmt.Sprintf("Empresa CIF: %s", req.CIF))
	pdf.Ln(6)
	pdf.Cell(0, 8, fmt.Sprintf("Periodo: %s - %s", req.From.Format("02/01/2006"), req.To.Format("02/01/2006")))
	pdf.Ln(6)
	pdf.Cell(0, 8, fmt.Sprintf("Generado: %s UTC", time.Now().UTC().Format("02/01/2006 15:04")))
	pdf.Ln(10)

	pdf.SetFont("Arial", "B", 9)
	pdf.Cell(25, 7, "NIF")
	pdf.Cell(40, 7, "Nombre")
	pdf.Cell(20, 7, "Tipo")
	pdf.Cell(35, 7, "Fecha/hora")
	pdf.Cell(25, 7, "Hora")
	pdf.Cell(45, 7, "Hash")
	pdf.Ln(7)
	pdf.SetFont("Arial", "", 8)

	for _, r := range records {
		hash := r.EventHash
		if len(hash) > 12 {
			hash = hash[:12] + "..."
		}
		pdf.Cell(25, 6, r.EmployeeNIF)
		pdf.Cell(40, 6, truncate(r.EmployeeName, 22))
		pdf.Cell(20, 6, string(r.EventType))
		pdf.Cell(35, 6, r.RecordedAt.Format("02/01/06 15:04"))
		pdf.Cell(25, 6, r.HourType)
		pdf.Cell(45, 6, hash)
		pdf.Ln(6)
	}

	var buf []byte
	w := &bytesWriter{buf: &buf}
	if err := pdf.Output(w); err != nil {
		return nil, err
	}
	return buf, nil
}

type bytesWriter struct {
	buf *[]byte
}

func (w *bytesWriter) Write(p []byte) (int, error) {
	*w.buf = append(*w.buf, p...)
	return len(p), nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n-3] + "..."
}
