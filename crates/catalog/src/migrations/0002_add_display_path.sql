ALTER TABLE skill_instance ADD COLUMN display_path TEXT;
UPDATE skill_instance SET display_path = path WHERE display_path IS NULL;
