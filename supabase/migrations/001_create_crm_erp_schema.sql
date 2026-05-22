-- Supabase Migration: Create CRM/ERP Tables
-- Run this in Supabase SQL Editor

-- Drop existing tables if they exist (for fresh setup)
DROP TABLE IF EXISTS lead_history CASCADE;
DROP TABLE IF EXISTS visited_leads CASCADE;
DROP TABLE IF EXISTS leads CASCADE;

-- Create leads table
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  alias VARCHAR NOT NULL UNIQUE,
  project VARCHAR NOT NULL,
  area VARCHAR NOT NULL,
  city VARCHAR DEFAULT 'Mumbai',
  budget VARCHAR,
  buyer_type VARCHAR,
  assigned_to VARCHAR,
  assigned_role VARCHAR,
  data_loan VARCHAR DEFAULT 'Inactive',
  loan_expires_at TIMESTAMP,
  call_status VARCHAR,
  visit_status VARCHAR,
  broker_lock VARCHAR DEFAULT 'Not Started',
  lock_expires_at TIMESTAMP,
  booking_stage VARCHAR,
  brokerage_status VARCHAR,
  lead_quality VARCHAR,
  data_quality VARCHAR,
  followup_at TIMESTAMP,
  calls_attempted INTEGER DEFAULT 0,
  next_action TEXT,
  
  -- Performance & Analytics
  view_count INTEGER DEFAULT 0,
  visit_duration INTEGER DEFAULT 0,
  visited_at TIMESTAMP,
  last_interaction TIMESTAMP,
  
  -- CRM/ERP IDs
  crm_id VARCHAR,
  erp_id VARCHAR,
  synced_at TIMESTAMP,
  
  -- Metadata
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  created_by VARCHAR,
  notes TEXT
);

-- Create visited_leads table
CREATE TABLE visited_leads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL UNIQUE REFERENCES leads(id) ON DELETE CASCADE,
  first_visited TIMESTAMP DEFAULT NOW(),
  last_visited TIMESTAMP DEFAULT NOW(),
  visit_count INTEGER DEFAULT 1,
  total_duration INTEGER DEFAULT 0,
  actions TEXT[] DEFAULT '{}',
  conversion_status VARCHAR DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create lead_history table (audit trail)
CREATE TABLE lead_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  action VARCHAR NOT NULL,
  old_value JSONB,
  new_value JSONB,
  changed_by VARCHAR,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_leads_project ON leads(project);
CREATE INDEX idx_leads_area ON leads(area);
CREATE INDEX idx_leads_quality ON leads(lead_quality);
CREATE INDEX idx_leads_status ON leads(call_status);
CREATE INDEX idx_leads_assigned ON leads(assigned_to);
CREATE INDEX idx_leads_broker_lock ON leads(broker_lock);
CREATE INDEX idx_leads_booking ON leads(booking_stage);
CREATE INDEX idx_leads_brokerage ON leads(brokerage_status);
CREATE INDEX idx_leads_created ON leads(created_at DESC);
CREATE INDEX idx_leads_updated ON leads(updated_at DESC);
CREATE INDEX idx_visited_leads_converted ON visited_leads(conversion_status);
CREATE INDEX idx_visited_leads_last ON visited_leads(last_visited DESC);
CREATE INDEX idx_history_lead ON lead_history(lead_id);
CREATE INDEX idx_history_created ON lead_history(created_at DESC);

-- Create full-text search index
CREATE INDEX idx_leads_search ON leads USING GIN(to_tsvector('english', 
  alias || ' ' || project || ' ' || area || ' ' || COALESCE(assigned_to, '') || ' ' || COALESCE(next_action, '')
));

-- Enable Row Level Security
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE visited_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_history ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (allow all authenticated users for now)
CREATE POLICY "Enable read access for authenticated users" ON leads
  FOR SELECT USING (true);

CREATE POLICY "Enable write access for authenticated users" ON leads
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" ON leads
  FOR UPDATE USING (true);

CREATE POLICY "Enable read access for visited_leads" ON visited_leads
  FOR SELECT USING (true);

CREATE POLICY "Enable write access for visited_leads" ON visited_leads
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update for visited_leads" ON visited_leads
  FOR UPDATE USING (true);

CREATE POLICY "Enable read access for lead_history" ON lead_history
  FOR SELECT USING (true);

CREATE POLICY "Enable write access for lead_history" ON lead_history
  FOR INSERT WITH CHECK (true);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER leads_updated_at BEFORE UPDATE ON leads
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER visited_leads_updated_at BEFORE UPDATE ON visited_leads
  FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Create materialized view for metrics (optional - for performance)
CREATE MATERIALIZED VIEW leads_metrics AS
SELECT
  COUNT(*) as total_leads,
  COUNT(CASE WHEN lead_quality = 'Hot' THEN 1 END) as hot_leads,
  COUNT(CASE WHEN view_count > 0 THEN 1 END) as visited_leads,
  COUNT(CASE WHEN lead_quality = 'Cold' OR brokerage_status = 'Blocked' THEN 1 END) as lost_leads,
  AVG(calls_attempted) as avg_followups,
  COUNT(CASE WHEN view_count > 0 THEN 1 END)::FLOAT / COUNT(*) as conversion_rate
FROM leads;

-- Create index on materialized view
CREATE UNIQUE INDEX idx_leads_metrics ON leads_metrics(total_leads);
