CREATE EXTENSION vector;

CREATE TABLE infrastructure_images (
  id SERIAL PRIMARY KEY,
  
  -- File identification
  filename VARCHAR(255) UNIQUE NOT NULL,
  
  -- Asset information (from Nova analysis)
  asset_type VARCHAR(50),
  asset_subtype VARCHAR(50),
  material_type VARCHAR(100),
  
  -- Defect analysis
  defect_detected BOOLEAN DEFAULT FALSE,
  defect_types TEXT[],
  severity_level VARCHAR(20),
  confidence_score FLOAT,
  requires_action BOOLEAN DEFAULT FALSE,
  
  -- Descriptions for semantic search
  description TEXT,
  condition_assessment TEXT,
  safety_concerns TEXT,
  maintenance_recommendations TEXT,
  
  -- Context
  environmental_factors TEXT,
  approximate_age_condition VARCHAR(50),
  location_context VARCHAR(50),
  
  -- Searchable tags
  tags TEXT[],
  
  -- Vector embeddings for semantic search
  description_embedding vector(1024),  -- Amazon Titan embeddings are 1024-dim
  combined_embedding vector(1024),     -- For combined text search
  
  -- Metadata
  analysis_timestamp TIMESTAMP DEFAULT NOW(),
  model_used VARCHAR(100)
);

