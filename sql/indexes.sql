-- Indexes for efficient querying
CREATE INDEX idx_asset_type ON infrastructure_images(asset_type);
CREATE INDEX idx_defect_detected ON infrastructure_images(defect_detected);
CREATE INDEX idx_severity ON infrastructure_images(severity_level);
CREATE INDEX idx_tags ON infrastructure_images USING GIN(tags);

-- Vector similarity search indexes
CREATE INDEX idx_description_embedding ON infrastructure_images 
  USING ivfflat (description_embedding vector_cosine_ops) WITH (lists = 100);
CREATE INDEX idx_combined_embedding ON infrastructure_images 
  USING ivfflat (combined_embedding vector_cosine_ops) WITH (lists = 100);