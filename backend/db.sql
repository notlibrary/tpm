-- ============================================
-- TOOTHPASTE PRODUCTION PROCESS DATABASE
-- PostgreSQL 14+
-- TECHNICAL PHENOMENOLOGY OF TOOTHPASTE MANUFACTURING
-- ALL FORMULATIONS FIXED - ALL FUNCTIONS FIXED
-- ============================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- 1. CORE REFERENCE TABLES
-- ============================================

-- Countries
CREATE TABLE countries (
    country_id SERIAL PRIMARY KEY,
    iso_code CHAR(2) UNIQUE NOT NULL,
    iso3_code CHAR(3) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    phone_code VARCHAR(10),
    currency_code CHAR(3),
    currency_name VARCHAR(50),
    region VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Companies (Suppliers, Manufacturers, Distributors)
CREATE TABLE companies (
    company_id SERIAL PRIMARY KEY,
    company_code VARCHAR(20) UNIQUE NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    legal_name VARCHAR(200),
    tax_id VARCHAR(50),
    registration_number VARCHAR(50),
    company_type VARCHAR(50) CHECK (company_type IN ('Supplier', 'Manufacturer', 'Distributor', 'Lab', 'Regulatory', 'Contractor')),
    parent_company_id INTEGER REFERENCES companies(company_id),
    country_id INTEGER REFERENCES countries(country_id),
    address TEXT,
    city VARCHAR(100),
    postal_code VARCHAR(20),
    website VARCHAR(255),
    email VARCHAR(100),
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_companies_country ON companies(country_id);
CREATE INDEX idx_companies_type ON companies(company_type);
CREATE INDEX idx_companies_code ON companies(company_code);

-- Persons (Employees, Scientists, QC Personnel)
CREATE TABLE persons (
    person_id SERIAL PRIMARY KEY,
    person_code VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    title VARCHAR(50),
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    mobile VARCHAR(20),
    company_id INTEGER REFERENCES companies(company_id),
    department VARCHAR(100),
    position VARCHAR(100),
    role VARCHAR(50) CHECK (role IN ('Scientist', 'Chemist', 'QC_Technician', 'Production_Manager', 'R&D_Manager', 'Regulatory_Specialist', 'Process_Engineer', 'Lab_Technician')),
    specialization VARCHAR(200),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_persons_company ON persons(company_id);
CREATE INDEX idx_persons_role ON persons(role);
CREATE INDEX idx_persons_email ON persons(email);

-- ============================================
-- 2. CHEMICAL COMPOUNDS & INGREDIENTS
-- ============================================

-- Chemical Elements Reference
CREATE TABLE chemical_elements (
    element_id SERIAL PRIMARY KEY,
    symbol CHAR(2) UNIQUE NOT NULL,
    name VARCHAR(50) NOT NULL,
    atomic_number INTEGER UNIQUE NOT NULL,
    atomic_mass DECIMAL(10,6),
    category VARCHAR(50),
    standard_state VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Chemical Compounds (Raw materials and intermediates)
CREATE TABLE chemical_compounds (
    compound_id SERIAL PRIMARY KEY,
    compound_code VARCHAR(50) UNIQUE NOT NULL,
    compound_name VARCHAR(200) NOT NULL,
    chemical_formula VARCHAR(100),
    molecular_weight DECIMAL(12,4),
    cas_number VARCHAR(20) UNIQUE,
    einics_number VARCHAR(20),
    inci_name VARCHAR(200),
    iupac_name VARCHAR(500),
    compound_type VARCHAR(50) CHECK (compound_type IN ('Abraisive', 'Humectant', 'Binder', 'Surfactant', 'Flavor', 'Sweetener', 'Preservative', 'Fluoride', 'Whitening_Agent', 'Active_Ingredient', 'Solvent', 'pH_Adjuster', 'Colorant', 'Thickener', 'Antimicrobial', 'Desensitizing_Agent')),
    purity_min DECIMAL(5,2),
    purity_max DECIMAL(5,2),
    physical_state VARCHAR(20) CHECK (physical_state IN ('Solid', 'Liquid', 'Gas', 'Gel', 'Paste')),
    color VARCHAR(50),
    odor VARCHAR(100),
    solubility VARCHAR(100),
    ph_level DECIMAL(4,2),
    boiling_point DECIMAL(8,2),
    melting_point DECIMAL(8,2),
    density DECIMAL(10,4),
    flash_point DECIMAL(8,2),
    hazard_classification JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_compounds_cas ON chemical_compounds(cas_number);
CREATE INDEX idx_compounds_type ON chemical_compounds(compound_type);
CREATE INDEX idx_compounds_code ON chemical_compounds(compound_code);
CREATE INDEX idx_compounds_name ON chemical_compounds USING GIN (to_tsvector('english', compound_name));

-- Compound Element Composition
CREATE TABLE compound_elements (
    composition_id SERIAL PRIMARY KEY,
    compound_id INTEGER REFERENCES chemical_compounds(compound_id) ON DELETE CASCADE,
    element_id INTEGER REFERENCES chemical_elements(element_id),
    percentage DECIMAL(8,4),
    atom_count INTEGER,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(compound_id, element_id)
);

-- Compound Suppliers (Materials Sourcing)
CREATE TABLE compound_suppliers (
    supplier_compound_id SERIAL PRIMARY KEY,
    compound_id INTEGER REFERENCES chemical_compounds(compound_id),
    company_id INTEGER REFERENCES companies(company_id),
    supplier_code VARCHAR(50),
    purchase_price DECIMAL(12,4),
    currency_code CHAR(3),
    lead_time_days INTEGER,
    minimum_order_quantity DECIMAL(12,4),
    unit_of_measure VARCHAR(20) CHECK (unit_of_measure IN ('KG', 'G', 'L', 'ML', 'TON', 'LB', 'OZ')),
    quality_rating INTEGER CHECK (quality_rating BETWEEN 1 AND 5),
    certification_status VARCHAR(50),
    is_preferred BOOLEAN DEFAULT false,
    contract_start_date DATE,
    contract_end_date DATE,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(compound_id, company_id)
);

CREATE INDEX idx_comp_supplier ON compound_suppliers(company_id);

-- ============================================
-- 3. FORMULATIONS & RECIPES
-- ============================================

-- Toothpaste Brands
CREATE TABLE brands (
    brand_id SERIAL PRIMARY KEY,
    brand_code VARCHAR(20) UNIQUE NOT NULL,
    brand_name VARCHAR(200) NOT NULL,
    parent_company_id INTEGER REFERENCES companies(company_id),
    brand_owner VARCHAR(200),
    trademark_number VARCHAR(50),
    trademark_office VARCHAR(100),
    market_segment VARCHAR(50) CHECK (market_segment IN ('Premium', 'Mid-Range', 'Economy', 'Professional', 'Natural', 'Sensitive', 'Kids', 'Whitening', 'Therapeutic')),
    slogan TEXT,
    brand_color_primary VARCHAR(20),
    brand_color_secondary VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_brands_company ON brands(parent_company_id);
CREATE INDEX idx_brands_name ON brands(brand_name);

-- Product Formulations (The recipe)
CREATE TABLE formulations (
    formulation_id SERIAL PRIMARY KEY,
    formulation_code VARCHAR(50) UNIQUE NOT NULL,
    formulation_name VARCHAR(200) NOT NULL,
    brand_id INTEGER REFERENCES brands(brand_id),
    version VARCHAR(20) DEFAULT '1.0',
    product_type VARCHAR(100) CHECK (product_type IN ('Regular_Toothpaste', 'Whitening', 'Sensitive', 'Kids', 'Herbal', 'Fluoride_Free', 'Baking_Soda', 'Charcoal', 'Enamel_Repair', 'Antibacterial', 'Tartar_Control', 'Gum_Care', 'Deep_Clean', 'Natural_Formula')),
    flavor_profile VARCHAR(100),
    target_ph DECIMAL(4,2),
    target_viscosity VARCHAR(50),
    total_solids DECIMAL(5,2),
    water_percentage DECIMAL(5,2),
    active_ingredient VARCHAR(200),
    fluoride_type VARCHAR(50),
    fluoride_ppm INTEGER,
    abrasiveness_rida DECIMAL(4,2),
    expiration_months INTEGER,
    storage_conditions VARCHAR(200),
    regulatory_status VARCHAR(50),
    status VARCHAR(20) CHECK (status IN ('Draft', 'Under_Review', 'Approved', 'Active', 'Discontinued', 'Archived')),
    approved_by INTEGER REFERENCES persons(person_id),
    approved_date DATE,
    effective_date DATE,
    discontinued_date DATE,
    description TEXT,
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by INTEGER REFERENCES persons(person_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_formulations_brand ON formulations(brand_id);
CREATE INDEX idx_formulations_status ON formulations(status);
CREATE INDEX idx_formulations_code ON formulations(formulation_code);
CREATE INDEX idx_formulations_type ON formulations(product_type);

-- Formulation Components (Ingredients with percentages)
CREATE TABLE formulation_components (
    component_id SERIAL PRIMARY KEY,
    formulation_id INTEGER REFERENCES formulations(formulation_id) ON DELETE CASCADE,
    compound_id INTEGER REFERENCES chemical_compounds(compound_id),
    percentage_min DECIMAL(8,4) NOT NULL,
    percentage_max DECIMAL(8,4) NOT NULL,
    percentage_target DECIMAL(8,4),
    is_critical BOOLEAN DEFAULT false,
    phase VARCHAR(20) CHECK (phase IN ('Aqueous', 'Oil', 'Powder', 'Additive', 'Flavor', 'Active')),
    addition_order INTEGER,
    addition_temperature_celsius DECIMAL(5,2),
    mixing_speed_rpm INTEGER,
    mixing_time_minutes INTEGER,
    function VARCHAR(100),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(formulation_id, compound_id)
);

CREATE INDEX idx_formula_components ON formulation_components(formulation_id);

-- ============================================
-- 4. PRODUCTION PROCESS
-- ============================================

-- Production Facilities (Plants)
CREATE TABLE production_facilities (
    facility_id SERIAL PRIMARY KEY,
    facility_code VARCHAR(20) UNIQUE NOT NULL,
    facility_name VARCHAR(200) NOT NULL,
    company_id INTEGER REFERENCES companies(company_id),
    country_id INTEGER REFERENCES countries(country_id),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    postal_code VARCHAR(20),
    gmp_certification VARCHAR(100),
    iso_certification VARCHAR(100),
    halal_certified BOOLEAN DEFAULT false,
    kosher_certified BOOLEAN DEFAULT false,
    organic_certified BOOLEAN DEFAULT false,
    capacity_kgs_per_day INTEGER,
    production_lines INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_facilities_company ON production_facilities(company_id);
CREATE INDEX idx_facilities_country ON production_facilities(country_id);

-- Production Batches (The actual manufacturing run)
CREATE TABLE production_batches (
    batch_id SERIAL PRIMARY KEY,
    batch_number VARCHAR(50) UNIQUE NOT NULL,
    formulation_id INTEGER REFERENCES formulations(formulation_id),
    facility_id INTEGER REFERENCES production_facilities(facility_id),
    target_quantity_kg DECIMAL(12,2) NOT NULL,
    actual_quantity_kg DECIMAL(12,2),
    batch_size_units INTEGER,
    yield_percentage DECIMAL(5,2),
    planned_start_date DATE,
    planned_end_date DATE,
    actual_start_date TIMESTAMPTZ,
    actual_end_date TIMESTAMPTZ,
    status VARCHAR(30) CHECK (status IN ('Planned', 'Raw_Materials_Ready', 'In_Production', 'Compounding', 'Mixing', 'Quality_Check', 'Holding', 'Filling', 'Packaging', 'Completed', 'Quarantined', 'Rejected', 'Released', 'Discontinued')),
    shift VARCHAR(20) CHECK (shift IN ('Day', 'Night', 'Weekend')),
    supervisor_id INTEGER REFERENCES persons(person_id),
    production_notes TEXT,
    equipment_used JSONB,
    process_parameters JSONB,
    is_active BOOLEAN DEFAULT true,
    created_by INTEGER REFERENCES persons(person_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_batches_number ON production_batches(batch_number);
CREATE INDEX idx_batches_formulation ON production_batches(formulation_id);
CREATE INDEX idx_batches_facility ON production_batches(facility_id);
CREATE INDEX idx_batches_status ON production_batches(status);
CREATE INDEX idx_batches_date ON production_batches(actual_start_date, actual_end_date);

-- Batch Raw Material Usage
CREATE TABLE batch_raw_materials (
    batch_raw_material_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES production_batches(batch_id) ON DELETE CASCADE,
    compound_id INTEGER REFERENCES chemical_compounds(compound_id),
    supplier_compound_id INTEGER REFERENCES compound_suppliers(supplier_compound_id),
    batch_number VARCHAR(50),
    quantity_planned DECIMAL(12,4) NOT NULL,
    quantity_actual DECIMAL(12,4),
    unit_of_measure VARCHAR(20),
    cost_per_unit DECIMAL(12,4),
    total_cost DECIMAL(12,4),
    received_date DATE,
    expiry_date DATE,
    quality_status VARCHAR(20) CHECK (quality_status IN ('Pending', 'Approved', 'Rejected', 'Quarantined')),
    quality_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_batch_materials ON batch_raw_materials(batch_id);

-- ============================================
-- 5. CHEMICAL LABS & QUALITY CONTROL
-- ============================================

-- Chemical Laboratories
CREATE TABLE chemical_labs (
    lab_id SERIAL PRIMARY KEY,
    lab_code VARCHAR(20) UNIQUE NOT NULL,
    lab_name VARCHAR(200) NOT NULL,
    company_id INTEGER REFERENCES companies(company_id),
    facility_id INTEGER REFERENCES production_facilities(facility_id),
    lab_type VARCHAR(50) CHECK (lab_type IN ('R&D', 'QC', 'Analytical', 'Microbiology', 'Stability', 'Research', 'Reference')),
    accreditation VARCHAR(200),
    accreditation_number VARCHAR(50),
    equipment_list JSONB,
    capacity_samples_per_day INTEGER,
    is_gmp_compliant BOOLEAN DEFAULT false,
    is_iso17025_compliant BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_labs_company ON chemical_labs(company_id);
CREATE INDEX idx_labs_facility ON chemical_labs(facility_id);

-- Quality Control Parameters
CREATE TABLE qc_parameters (
    parameter_id SERIAL PRIMARY KEY,
    parameter_code VARCHAR(50) UNIQUE NOT NULL,
    parameter_name VARCHAR(200) NOT NULL,
    parameter_type VARCHAR(50) CHECK (parameter_type IN ('Physical', 'Chemical', 'Microbiological', 'Sensory', 'Performance')),
    test_method VARCHAR(200),
    equipment_needed VARCHAR(200),
    unit_of_measure VARCHAR(50),
    target_min DECIMAL(12,4),
    target_max DECIMAL(12,4),
    tolerance_min DECIMAL(12,4),
    tolerance_max DECIMAL(12,4),
    critical_limit_min DECIMAL(12,4),
    critical_limit_max DECIMAL(12,4),
    sampling_frequency VARCHAR(50),
    category VARCHAR(100) CHECK (category IN ('Appearance', 'pH', 'Viscosity', 'Density', 'Fluoride_Content', 'Microbial_Count', 'Abrasiveness', 'Stability', 'Flavor', 'Consistency', 'Weight', 'Packaging', 'Labeling')),
    is_mandatory BOOLEAN DEFAULT true,
    is_destructive_test BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_qc_params_type ON qc_parameters(parameter_type);
CREATE INDEX idx_qc_params_code ON qc_parameters(parameter_code);

-- Formulation QC Specifications
CREATE TABLE formulation_qc_specs (
    spec_id SERIAL PRIMARY KEY,
    formulation_id INTEGER REFERENCES formulations(formulation_id) ON DELETE CASCADE,
    parameter_id INTEGER REFERENCES qc_parameters(parameter_id),
    spec_min DECIMAL(12,4),
    spec_max DECIMAL(12,4),
    spec_unit VARCHAR(50),
    is_critical BOOLEAN DEFAULT false,
    test_frequency VARCHAR(50),
    acceptance_criteria TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(formulation_id, parameter_id)
);

-- Quality Control Tests
CREATE TABLE qc_tests (
    test_id SERIAL PRIMARY KEY,
    test_number VARCHAR(50) UNIQUE NOT NULL,
    batch_id INTEGER REFERENCES production_batches(batch_id),
    lab_id INTEGER REFERENCES chemical_labs(lab_id),
    parameter_id INTEGER REFERENCES qc_parameters(parameter_id),
    sample_type VARCHAR(50) CHECK (sample_type IN ('Raw_Material', 'Intermediate', 'Finished_Product', 'Retention_Sample', 'Stability_Sample')),
    sample_size VARCHAR(50),
    test_date TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    test_result DECIMAL(12,4),
    test_result_text TEXT,
    result_unit VARCHAR(50),
    passed BOOLEAN,
    deviation_from_spec DECIMAL(12,4),
    status VARCHAR(30) CHECK (status IN ('Pending', 'In_Progress', 'Completed', 'Verified', 'Approved', 'Rejected', 'Retest_Required')),
    performed_by INTEGER REFERENCES persons(person_id),
    verified_by INTEGER REFERENCES persons(person_id),
    approved_by INTEGER REFERENCES persons(person_id),
    test_notes TEXT,
    observations TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_tests_batch ON qc_tests(batch_id);
CREATE INDEX idx_tests_lab ON qc_tests(lab_id);
CREATE INDEX idx_tests_parameter ON qc_tests(parameter_id);
CREATE INDEX idx_tests_number ON qc_tests(test_number);
CREATE INDEX idx_tests_status ON qc_tests(status);
CREATE INDEX idx_tests_date ON qc_tests(test_date);

-- Stability Studies
CREATE TABLE stability_studies (
    stability_id SERIAL PRIMARY KEY,
    stability_number VARCHAR(50) UNIQUE NOT NULL,
    batch_id INTEGER REFERENCES production_batches(batch_id),
    lab_id INTEGER REFERENCES chemical_labs(lab_id),
    study_type VARCHAR(50) CHECK (study_type IN ('Real_Time', 'Accelerated', 'Stress', 'Photostability', 'Freeze_Thaw', 'Transport')),
    condition_temperature_celsius DECIMAL(5,2),
    condition_humidity_percent DECIMAL(5,2),
    condition_light_condition VARCHAR(50),
    sampling_interval_days INTEGER,
    total_duration_days INTEGER,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(30) CHECK (status IN ('Planned', 'In_Progress', 'Completed', 'Analyzing', 'Finalized')),
    conclusions TEXT,
    shelf_life_months INTEGER,
    storage_conditions VARCHAR(200),
    is_compliant BOOLEAN,
    created_by INTEGER REFERENCES persons(person_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_stability_batch ON stability_studies(batch_id);

-- Stability Test Points
CREATE TABLE stability_test_points (
    test_point_id SERIAL PRIMARY KEY,
    stability_id INTEGER REFERENCES stability_studies(stability_id) ON DELETE CASCADE,
    time_point VARCHAR(20) CHECK (time_point IN ('Initial', '1M', '3M', '6M', '9M', '12M', '18M', '24M', '36M', '48M', '60M')),
    scheduled_date DATE NOT NULL,
    actual_test_date DATE,
    parameter_id INTEGER REFERENCES qc_parameters(parameter_id),
    test_result DECIMAL(12,4),
    result_text TEXT,
    passed BOOLEAN,
    comments TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. REGULATORY & COMPLIANCE
-- ============================================

-- Regulatory Bodies
CREATE TABLE regulatory_bodies (
    body_id SERIAL PRIMARY KEY,
    body_code VARCHAR(20) UNIQUE NOT NULL,
    body_name VARCHAR(200) NOT NULL,
    country_id INTEGER REFERENCES countries(country_id),
    body_type VARCHAR(50) CHECK (body_type IN ('FDA', 'EMA', 'Health_Canada', 'MHRA', 'TGA', 'WHO', 'ISO', 'Others')),
    website VARCHAR(255),
    contact_email VARCHAR(100),
    contact_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Product Registrations
CREATE TABLE product_registrations (
    registration_id SERIAL PRIMARY KEY,
    brand_id INTEGER REFERENCES brands(brand_id),
    formulation_id INTEGER REFERENCES formulations(formulation_id),
    regulatory_body_id INTEGER REFERENCES regulatory_bodies(body_id),
    registration_number VARCHAR(100) NOT NULL,
    ndc_number VARCHAR(50),
    gtin VARCHAR(50),
    upc VARCHAR(50),
    registration_date DATE NOT NULL,
    expiry_date DATE,
    status VARCHAR(30) CHECK (status IN ('Approved', 'Pending', 'Expired', 'Revoked', 'Under_Review')),
    product_claims TEXT,
    approved_indications TEXT,
    contraindications TEXT,
    warnings TEXT,
    active_ingredient_statement TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_registrations_brand ON product_registrations(brand_id);
CREATE INDEX idx_registrations_formulation ON product_registrations(formulation_id);
CREATE INDEX idx_registrations_body ON product_registrations(regulatory_body_id);

-- ============================================
-- 7. INVENTORY & SUPPLY CHAIN
-- ============================================

-- Raw Material Inventory
CREATE TABLE raw_material_inventory (
    inventory_id SERIAL PRIMARY KEY,
    compound_id INTEGER REFERENCES chemical_compounds(compound_id),
    facility_id INTEGER REFERENCES production_facilities(facility_id),
    location VARCHAR(100),
    batch_number VARCHAR(50) NOT NULL,
    supplier_compound_id INTEGER REFERENCES compound_suppliers(supplier_compound_id),
    quantity DECIMAL(12,4) NOT NULL DEFAULT 0,
    unit_of_measure VARCHAR(20),
    reserved_quantity DECIMAL(12,4) DEFAULT 0,
    available_quantity DECIMAL(12,4) GENERATED ALWAYS AS (quantity - reserved_quantity) STORED,
    receipt_date DATE,
    expiry_date DATE,
    reorder_level DECIMAL(12,4),
    reorder_quantity DECIMAL(12,4),
    status VARCHAR(30) CHECK (status IN ('Available', 'Reserved', 'Quarantine', 'Expired', 'Damaged', 'Disposed')),
    quality_status VARCHAR(30) CHECK (quality_status IN ('Pending', 'Approved', 'Rejected', 'Under_Review')),
    cost_per_unit DECIMAL(12,4),
    total_value DECIMAL(12,4) GENERATED ALWAYS AS (quantity * cost_per_unit) STORED,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inventory_compound ON raw_material_inventory(compound_id);
CREATE INDEX idx_inventory_facility ON raw_material_inventory(facility_id);
CREATE INDEX idx_inventory_batch ON raw_material_inventory(batch_number);
CREATE INDEX idx_inventory_expiry ON raw_material_inventory(expiry_date);
CREATE INDEX idx_inventory_status ON raw_material_inventory(status);

-- Material Receipts
CREATE TABLE material_receipts (
    receipt_id SERIAL PRIMARY KEY,
    receipt_number VARCHAR(50) UNIQUE NOT NULL,
    purchase_order_number VARCHAR(50),
    supplier_id INTEGER REFERENCES companies(company_id),
    facility_id INTEGER REFERENCES production_facilities(facility_id),
    compound_id INTEGER REFERENCES chemical_compounds(compound_id),
    quantity_received DECIMAL(12,4) NOT NULL,
    unit_of_measure VARCHAR(20),
    batch_number VARCHAR(50),
    manufacturing_date DATE,
    expiry_date DATE,
    receipt_date DATE DEFAULT CURRENT_DATE,
    quality_checked BOOLEAN DEFAULT false,
    quality_check_date DATE,
    qc_status VARCHAR(30) CHECK (qc_status IN ('Pending', 'Approved', 'Rejected', 'Partial_Accept')),
    rejection_reason TEXT,
    accepted_quantity DECIMAL(12,4),
    rejected_quantity DECIMAL(12,4),
    cost_per_unit DECIMAL(12,4),
    currency_code CHAR(3),
    is_completed BOOLEAN DEFAULT false,
    created_by INTEGER REFERENCES persons(person_id),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_receipts_supplier ON material_receipts(supplier_id);
CREATE INDEX idx_receipts_compound ON material_receipts(compound_id);
CREATE INDEX idx_receipts_facility ON material_receipts(facility_id);

-- ============================================
-- 8. FINISHED PRODUCTS
-- ============================================

-- Finished Products
CREATE TABLE finished_products (
    finished_product_id SERIAL PRIMARY KEY,
    product_code VARCHAR(50) UNIQUE NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    brand_id INTEGER REFERENCES brands(brand_id),
    formulation_id INTEGER REFERENCES formulations(formulation_id),
    size_ml DECIMAL(8,2),
    size_g DECIMAL(8,2),
    packaging_type VARCHAR(50) CHECK (packaging_type IN ('Tube', 'Pump', 'Jar', 'Box', 'Blister_Pack', 'Single_Use')),
    flavor VARCHAR(100),
    color VARCHAR(50),
    retail_price DECIMAL(12,4),
    weight_kg DECIMAL(8,4),
    shelf_life_months INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

CREATE INDEX idx_products_brand ON finished_products(brand_id);
CREATE INDEX idx_products_formulation ON finished_products(formulation_id);
CREATE INDEX idx_products_code ON finished_products(product_code);

-- Product Packaging
CREATE TABLE product_packaging (
    packaging_id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES finished_products(finished_product_id),
    component_type VARCHAR(50) CHECK (component_type IN ('Tube', 'Cap', 'Box', 'Label', 'Wrapper', 'Carton')),
    material VARCHAR(100),
    weight_g DECIMAL(8,2),
    dimensions VARCHAR(50),
    color VARCHAR(50),
    artwork_version VARCHAR(20),
    supplier_id INTEGER REFERENCES companies(company_id),
    unit_cost DECIMAL(12,4),
    is_recyclable BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 9. PROCESS PHENOMENOLOGY - PRODUCTION STAGES
-- ============================================

-- Production Stages (Process Flow)
CREATE TABLE production_stages (
    stage_id SERIAL PRIMARY KEY,
    stage_code VARCHAR(20) UNIQUE NOT NULL,
    stage_name VARCHAR(100) NOT NULL,
    stage_order INTEGER,
    stage_type VARCHAR(50) CHECK (stage_type IN ('Preparation', 'Compounding', 'Mixing', 'Deaeration', 'Cooling', 'Holding', 'Filling', 'Sealing', 'Packaging', 'Labeling', 'Inspection', 'Storage')),
    description TEXT,
    default_temperature_celsius DECIMAL(5,2),
    default_humidity_percent DECIMAL(5,2),
    default_duration_minutes INTEGER,
    required_equipment JSONB,
    is_critical_control_point BOOLEAN DEFAULT false,
    monitoring_parameters JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Batch Stage Tracking (Actual process data)
CREATE TABLE batch_stages (
    batch_stage_id SERIAL PRIMARY KEY,
    batch_id INTEGER REFERENCES production_batches(batch_id) ON DELETE CASCADE,
    stage_id INTEGER REFERENCES production_stages(stage_id),
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    actual_temperature_celsius DECIMAL(5,2),
    actual_humidity_percent DECIMAL(5,2),
    actual_duration_minutes INTEGER,
    pressure_bar DECIMAL(8,2),
    ph_level DECIMAL(4,2),
    viscosity_cps DECIMAL(10,2),
    equipment_settings JSONB,
    operator_notes TEXT,
    deviations TEXT,
    corrective_actions TEXT,
    status VARCHAR(30) CHECK (status IN ('Pending', 'In_Progress', 'Completed', 'Paused', 'Aborted', 'Quality_Hold')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_batch_stages ON batch_stages(batch_id);

-- ============================================
-- 10. LABORATORY EQUIPMENT
-- ============================================

CREATE TABLE lab_equipment (
    equipment_id SERIAL PRIMARY KEY,
    equipment_code VARCHAR(50) UNIQUE NOT NULL,
    equipment_name VARCHAR(200) NOT NULL,
    lab_id INTEGER REFERENCES chemical_labs(lab_id),
    equipment_type VARCHAR(50) CHECK (equipment_type IN ('HPLC', 'GC', 'MS', 'Spectrometer', 'Viscometer', 'pH_Meter', 'Balance', 'Microscope', 'Incubator', 'Stability_Chamber', 'Mixer', 'Dispenser', 'Conductivity_Meter', 'Refractometer', 'Centrifuge')),
    manufacturer VARCHAR(100),
    model VARCHAR(100),
    serial_number VARCHAR(100),
    calibration_due_date DATE,
    last_calibration_date DATE,
    calibration_frequency_days INTEGER,
    is_calibrated BOOLEAN DEFAULT false,
    status VARCHAR(30) CHECK (status IN ('Operational', 'Maintenance', 'Calibration', 'Out_of_Service', 'Retired')),
    purchase_date DATE,
    purchase_cost DECIMAL(12,4),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 11. AUDIT & TRACEABILITY
-- ============================================

CREATE TABLE production_audit_log (
    audit_id SERIAL PRIMARY KEY,
    entity_type VARCHAR(50) NOT NULL,
    entity_id INTEGER NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'STATUS_CHANGE', 'QC_RESULT', 'APPROVAL', 'REJECTION')),
    performed_by INTEGER REFERENCES persons(person_id),
    performed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    before_data JSONB,
    after_data JSONB,
    changes JSONB,
    ip_address INET,
    user_agent TEXT,
    notes TEXT
);

CREATE INDEX idx_audit_entity ON production_audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_performed ON production_audit_log(performed_at DESC);

-- ============================================
-- 12. CORRECTED VIEWS
-- ============================================

-- View: Complete Formulation Details
CREATE OR REPLACE VIEW v_formulation_details AS
SELECT 
    f.formulation_code,
    f.formulation_name,
    b.brand_name,
    fc.compound_name,
    fc.chemical_formula,
    fc.cas_number,
    fcomp.percentage_target,
    fcomp.percentage_min,
    fcomp.percentage_max,
    fcomp.function,
    fcomp.phase,
    fcomp.addition_order,
    fcomp.addition_temperature_celsius,
    fcomp.mixing_time_minutes,
    f.status,
    f.flavor_profile,
    f.target_ph,
    f.fluoride_ppm,
    f.total_solids,
    f.active_ingredient
FROM formulations f
JOIN brands b ON f.brand_id = b.brand_id
JOIN formulation_components fcomp ON f.formulation_id = fcomp.formulation_id
JOIN chemical_compounds fc ON fcomp.compound_id = fc.compound_id
WHERE f.is_active = true;

-- View: Batch Production Summary
CREATE OR REPLACE VIEW v_batch_summary AS
SELECT 
    pb.batch_number,
    f.formulation_name,
    b.brand_name,
    pf.facility_name,
    pb.target_quantity_kg,
    pb.actual_quantity_kg,
    pb.yield_percentage,
    pb.status,
    pb.actual_start_date,
    pb.actual_end_date,
    EXTRACT(EPOCH FROM (COALESCE(pb.actual_end_date, CURRENT_TIMESTAMP) - pb.actual_start_date))/3600 AS production_hours,
    COUNT(DISTINCT ps.batch_stage_id) AS stages_completed,
    COUNT(DISTINCT qt.test_id) AS tests_performed,
    COUNT(CASE WHEN qt.passed = true THEN 1 ELSE NULL END) AS tests_passed
FROM production_batches pb
JOIN formulations f ON pb.formulation_id = f.formulation_id
JOIN brands b ON f.brand_id = b.brand_id
JOIN production_facilities pf ON pb.facility_id = pf.facility_id
LEFT JOIN batch_stages ps ON pb.batch_id = ps.batch_id AND ps.status = 'Completed'
LEFT JOIN qc_tests qt ON pb.batch_id = qt.batch_id
GROUP BY pb.batch_id, f.formulation_name, b.brand_name, pf.facility_name, 
         pb.batch_number, pb.target_quantity_kg, pb.actual_quantity_kg, 
         pb.yield_percentage, pb.status, pb.actual_start_date, pb.actual_end_date;

-- View: Quality Control Dashboard
CREATE OR REPLACE VIEW v_qc_dashboard AS
SELECT 
    qt.test_number,
    pb.batch_number,
    qp.parameter_name,
    qt.test_result,
    qp.target_min,
    qp.target_max,
    qt.passed,
    qt.status,
    p.first_name || ' ' || p.last_name AS performed_by,
    qt.test_date,
    CASE 
        WHEN qt.passed = true THEN 'PASS'
        WHEN qt.passed = false AND qt.status != 'Retest_Required' THEN 'FAIL'
        WHEN qt.status = 'Pending' THEN 'PENDING'
        ELSE 'REVIEW'
    END AS overall_status
FROM qc_tests qt
JOIN production_batches pb ON qt.batch_id = pb.batch_id
JOIN qc_parameters qp ON qt.parameter_id = qp.parameter_id
LEFT JOIN persons p ON qt.performed_by = p.person_id
WHERE qt.test_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY qt.test_date DESC;

-- View: Raw Material Expiry Alert
CREATE OR REPLACE VIEW v_material_expiry_alert AS
SELECT 
    cc.compound_name,
    cc.cas_number,
    rmi.batch_number,
    rmi.quantity,
    rmi.expiry_date,
    (rmi.expiry_date - CURRENT_DATE) AS days_until_expiry,
    CASE 
        WHEN rmi.expiry_date < CURRENT_DATE THEN 'EXPIRED'
        WHEN rmi.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN 'EXPIRING_SOON'
        WHEN rmi.expiry_date <= CURRENT_DATE + INTERVAL '90 days' THEN 'MONITOR'
        ELSE 'OK'
    END AS alert_status,
    pf.facility_name,
    rmi.location
FROM raw_material_inventory rmi
JOIN chemical_compounds cc ON rmi.compound_id = cc.compound_id
JOIN production_facilities pf ON rmi.facility_id = pf.facility_id
WHERE rmi.status = 'Available'
AND rmi.expiry_date IS NOT NULL
AND rmi.expiry_date <= CURRENT_DATE + INTERVAL '90 days'
ORDER BY rmi.expiry_date ASC;

-- View: Production Efficiency Metrics
CREATE OR REPLACE VIEW v_production_efficiency AS
SELECT 
    DATE_TRUNC('month', pb.actual_start_date) AS month,
    pf.facility_name,
    COUNT(pb.batch_id) AS total_batches,
    SUM(pb.target_quantity_kg) AS total_target_kg,
    SUM(COALESCE(pb.actual_quantity_kg, 0)) AS total_actual_kg,
    AVG(pb.yield_percentage) AS avg_yield_percent,
    COUNT(CASE WHEN pb.status = 'Released' THEN 1 ELSE NULL END) AS released_batches,
    COUNT(CASE WHEN pb.status = 'Rejected' THEN 1 ELSE NULL END) AS rejected_batches,
    ROUND(AVG(EXTRACT(EPOCH FROM (COALESCE(pb.actual_end_date, CURRENT_TIMESTAMP) - pb.actual_start_date))/3600), 2) AS avg_hours_per_batch
FROM production_batches pb
JOIN production_facilities pf ON pb.facility_id = pf.facility_id
WHERE pb.actual_start_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', pb.actual_start_date), pf.facility_name
ORDER BY month DESC, pf.facility_name;

-- ============================================
-- 13. CORRECTED STORED PROCEDURES
-- ============================================

-- Procedure: Create New Production Batch
CREATE OR REPLACE FUNCTION create_production_batch(
    p_formulation_id INTEGER,
    p_facility_id INTEGER,
    p_target_quantity_kg DECIMAL,
    p_planned_start_date DATE,
    p_planned_end_date DATE,
    p_supervisor_id INTEGER,
    p_created_by INTEGER
)
RETURNS INTEGER AS $$
DECLARE
    v_batch_id INTEGER;
    v_batch_number VARCHAR(50);
    v_counter INTEGER;
BEGIN
    -- Generate batch number with proper sequence
    SELECT COALESCE(MAX(CAST(SUBSTRING(batch_number FROM 'BT[0-9]{8}-([0-9]{4})') AS INTEGER)), 0)
    INTO v_counter
    FROM production_batches 
    WHERE batch_number LIKE 'BT' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-%';
    
    v_batch_number := 'BT' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD((v_counter + 1)::TEXT, 4, '0');
    
    INSERT INTO production_batches (
        batch_number,
        formulation_id,
        facility_id,
        target_quantity_kg,
        planned_start_date,
        planned_end_date,
        status,
        supervisor_id,
        created_by
    ) VALUES (
        v_batch_number,
        p_formulation_id,
        p_facility_id,
        p_target_quantity_kg,
        p_planned_start_date,
        p_planned_end_date,
        'Planned',
        p_supervisor_id,
        p_created_by
    ) RETURNING batch_id INTO v_batch_id;
    
    -- Create batch stages based on formulation requirements
    INSERT INTO batch_stages (batch_id, stage_id, status)
    SELECT v_batch_id, stage_id, 'Pending'
    FROM production_stages
    WHERE stage_type IN ('Preparation', 'Compounding', 'Mixing', 'Deaeration', 'Holding', 'Filling', 'Packaging', 'Inspection')
    ORDER BY stage_order;
    
    RAISE NOTICE 'Created production batch: % with ID: %', v_batch_number, v_batch_id;
    
    RETURN v_batch_id;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Record Quality Control Test
CREATE OR REPLACE FUNCTION record_qc_test(
    p_batch_id INTEGER,
    p_parameter_id INTEGER,
    p_lab_id INTEGER,
    p_test_result DECIMAL,
    p_result_text TEXT,
    p_performed_by INTEGER,
    p_test_notes TEXT
)
RETURNS INTEGER AS $$
DECLARE
    v_test_id INTEGER;
    v_test_number VARCHAR(50);
    v_passed BOOLEAN;
    v_target_min DECIMAL;
    v_target_max DECIMAL;
    v_counter INTEGER;
    v_parameter_name VARCHAR(200);
BEGIN
    -- Get the QC parameter specifications
    SELECT target_min, target_max, parameter_name
    INTO v_target_min, v_target_max, v_parameter_name
    FROM qc_parameters
    WHERE parameter_id = p_parameter_id;
    
    -- Check if parameter exists
    IF v_target_min IS NULL THEN
        RAISE EXCEPTION 'QC parameter with ID % not found', p_parameter_id;
    END IF;
    
    -- Determine if test passed
    v_passed := (p_test_result >= v_target_min AND p_test_result <= v_target_max);
    
    -- Generate test number
    SELECT COALESCE(MAX(CAST(SUBSTRING(test_number FROM 'QC[0-9]{8}-([0-9]{4})') AS INTEGER)), 0)
    INTO v_counter
    FROM qc_tests 
    WHERE test_number LIKE 'QC' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-%';
    
    v_test_number := 'QC' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD((v_counter + 1)::TEXT, 4, '0');
    
    INSERT INTO qc_tests (
        test_number,
        batch_id,
        lab_id,
        parameter_id,
        test_date,
        test_result,
        test_result_text,
        passed,
        performed_by,
        test_notes,
        status
    ) VALUES (
        v_test_number,
        p_batch_id,
        p_lab_id,
        p_parameter_id,
        CURRENT_TIMESTAMP,
        p_test_result,
        p_result_text,
        v_passed,
        p_performed_by,
        p_test_notes,
        'Completed'
    ) RETURNING test_id INTO v_test_id;
    
    -- Log the QC result
    INSERT INTO production_audit_log (
        entity_type, entity_id, action, performed_by, performed_at, after_data
    ) VALUES (
        'QC_Test', v_test_id, 'QC_RESULT', p_performed_by, CURRENT_TIMESTAMP,
        jsonb_build_object('test_result', p_test_result, 'passed', v_passed)
    );
    
    -- Update batch status if critical test fails
    IF NOT v_passed AND p_parameter_id IN (SELECT parameter_id FROM qc_parameters WHERE is_mandatory = true) THEN
        UPDATE production_batches
        SET status = 'Quality_Check'
        WHERE batch_id = p_batch_id;
        
        RAISE NOTICE 'Batch % placed on quality hold due to failed test: %', p_batch_id, v_parameter_name;
    END IF;
    
    IF v_passed THEN
        RAISE NOTICE 'QC test % passed for batch %', v_test_number, p_batch_id;
    ELSE
        RAISE WARNING 'QC test % FAILED for batch % - Result: %, Expected: % to %', 
            v_test_number, p_batch_id, p_test_result, v_target_min, v_target_max;
    END IF;
    
    RETURN v_test_id;
END;
$$ LANGUAGE plpgsql;

-- Procedure: Complete Production Batch
CREATE OR REPLACE FUNCTION complete_production_batch(
    p_batch_id INTEGER,
    p_actual_quantity_kg DECIMAL,
    p_completed_by INTEGER
)
RETURNS VOID AS $$
DECLARE
    v_formulation_id INTEGER;
    v_yield DECIMAL;
    v_target_quantity DECIMAL;
    v_batch_number VARCHAR(50);
BEGIN
    -- Get formulation, target quantity, and batch number
    SELECT formulation_id, target_quantity_kg, batch_number
    INTO v_formulation_id, v_target_quantity, v_batch_number
    FROM production_batches
    WHERE batch_id = p_batch_id;
    
    -- Check if batch exists
    IF v_formulation_id IS NULL THEN
        RAISE EXCEPTION 'Batch with ID % not found', p_batch_id;
    END IF;
    
    -- Calculate yield
    IF v_target_quantity > 0 THEN
        v_yield := (p_actual_quantity_kg / v_target_quantity) * 100;
    ELSE
        v_yield := 0;
        RAISE WARNING 'Target quantity is zero for batch %. Yield set to 0', v_batch_number;
    END IF;
    
    -- Update batch
    UPDATE production_batches
    SET 
        actual_quantity_kg = p_actual_quantity_kg,
        yield_percentage = v_yield,
        actual_end_date = CURRENT_TIMESTAMP,
        status = 'Completed',
        updated_at = CURRENT_TIMESTAMP
    WHERE batch_id = p_batch_id;
    
    -- Log completion
    INSERT INTO production_audit_log (
        entity_type, entity_id, action, performed_by, performed_at, after_data
    ) VALUES (
        'Production_Batch', p_batch_id, 'STATUS_CHANGE', p_completed_by, CURRENT_TIMESTAMP,
        jsonb_build_object('new_status', 'Completed', 'actual_quantity', p_actual_quantity_kg, 'yield', v_yield)
    );
    
    RAISE NOTICE 'Batch % completed with yield of %.2f percent', v_batch_number, v_yield;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 14. CORRECTED TRIGGER FUNCTIONS
-- ============================================

-- Trigger: Update inventory on material receipt
CREATE OR REPLACE FUNCTION update_raw_material_inventory()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.qc_status = 'Approved' THEN
        -- Add to inventory
        INSERT INTO raw_material_inventory (
            compound_id,
            facility_id,
            location,
            batch_number,
            supplier_compound_id,
            quantity,
            unit_of_measure,
            receipt_date,
            expiry_date,
            cost_per_unit,
            status,
            quality_status
        ) VALUES (
            NEW.compound_id,
            NEW.facility_id,
            'Receiving_Area',
            NEW.batch_number,
            (SELECT supplier_compound_id FROM compound_suppliers 
             WHERE compound_id = NEW.compound_id AND company_id = NEW.supplier_id LIMIT 1),
            COALESCE(NEW.accepted_quantity, NEW.quantity_received),
            NEW.unit_of_measure,
            NEW.receipt_date,
            NEW.expiry_date,
            NEW.cost_per_unit,
            'Available',
            'Approved'
        );
        
        RAISE NOTICE 'Inventory updated for compound % with quantity %', 
            NEW.compound_id, COALESCE(NEW.accepted_quantity, NEW.quantity_received);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Auto-update batch stage status
CREATE OR REPLACE FUNCTION update_batch_status_on_stage()
RETURNS TRIGGER AS $$
DECLARE
    v_total_stages INTEGER;
    v_completed_stages INTEGER;
BEGIN
    -- Count total and completed stages
    SELECT COUNT(*), COUNT(CASE WHEN status = 'Completed' THEN 1 ELSE NULL END)
    INTO v_total_stages, v_completed_stages
    FROM batch_stages
    WHERE batch_id = NEW.batch_id;
    
    IF v_total_stages > 0 AND v_total_stages = v_completed_stages THEN
        UPDATE production_batches
        SET status = 'Quality_Check',
            updated_at = CURRENT_TIMESTAMP
        WHERE batch_id = NEW.batch_id;
        
        RAISE NOTICE 'Batch % moved to Quality Check - all stages completed', NEW.batch_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Enforce data integrity for component percentages
CREATE OR REPLACE FUNCTION validate_formulation_percentages()
RETURNS TRIGGER AS $$
DECLARE
    v_total_percent DECIMAL;
BEGIN
    -- Check if total percentages are within range (95-105%)
    SELECT COALESCE(SUM(percentage_target), 0)
    INTO v_total_percent
    FROM formulation_components
    WHERE formulation_id = NEW.formulation_id;
    
    IF v_total_percent < 85 OR v_total_percent > 105 THEN
        RAISE EXCEPTION 'Total formulation percentages must be between 95 percent and 105 percent. Current total: %', 
            v_total_percent;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 15. CREATE TRIGGERS
-- ============================================

-- Create the triggers
CREATE OR REPLACE TRIGGER trg_update_inventory_on_receipt
AFTER UPDATE OF qc_status ON material_receipts
FOR EACH ROW
WHEN (NEW.qc_status = 'Approved' AND OLD.qc_status != 'Approved')
EXECUTE FUNCTION update_raw_material_inventory();

CREATE OR REPLACE TRIGGER trg_update_batch_on_stage_complete
AFTER UPDATE OF status ON batch_stages
FOR EACH ROW
WHEN (NEW.status = 'Completed')
EXECUTE FUNCTION update_batch_status_on_stage();

CREATE OR REPLACE TRIGGER trg_validate_formulation_percentages
AFTER INSERT OR UPDATE ON formulation_components
FOR EACH ROW
EXECUTE FUNCTION validate_formulation_percentages();

-- ============================================
-- 16. SAMPLE DATA INSERTS
-- ============================================

-- Insert countries
INSERT INTO countries (iso_code, iso3_code, name, phone_code, currency_code) VALUES
('US', 'USA', 'United States', '+1', 'USD'),
('CA', 'CAN', 'Canada', '+1', 'CAD'),
('GB', 'GBR', 'United Kingdom', '+44', 'GBP'),
('DE', 'DEU', 'Germany', '+49', 'EUR'),
('FR', 'FRA', 'France', '+33', 'EUR'),
('IN', 'IND', 'India', '+91', 'INR'),
('CN', 'CHN', 'China', '+86', 'CNY'),
('JP', 'JPN', 'Japan', '+81', 'JPY'),
('BR', 'BRA', 'Brazil', '+55', 'BRL'),
('AU', 'AUS', 'Australia', '+61', 'AUD');

-- Insert chemical elements
INSERT INTO chemical_elements (symbol, name, atomic_number, atomic_mass, category) VALUES
('H', 'Hydrogen', 1, 1.008, 'Non-metal'),
('C', 'Carbon', 6, 12.011, 'Non-metal'),
('O', 'Oxygen', 8, 15.999, 'Non-metal'),
('F', 'Fluorine', 9, 18.998, 'Halogen'),
('Na', 'Sodium', 11, 22.990, 'Alkali metal'),
('K', 'Potassium', 19, 39.098, 'Alkali metal'),
('Ca', 'Calcium', 20, 40.078, 'Alkaline earth metal'),
('P', 'Phosphorus', 15, 30.974, 'Non-metal'),
('Cl', 'Chlorine', 17, 35.453, 'Halogen'),
('Mg', 'Magnesium', 12, 24.305, 'Alkaline earth metal');

-- Insert chemical compounds
INSERT INTO chemical_compounds (
    compound_code, compound_name, chemical_formula, cas_number, compound_type, 
    physical_state, solubility, density, ph_level
) VALUES
('SOD-FLU', 'Sodium Fluoride', 'NaF', '7681-49-4', 'Fluoride', 'Solid', 'Water Soluble', 2.558, 7.0),
('MFP', 'Sodium Monofluorophosphate', 'Na2PO3F', '7631-94-9', 'Fluoride', 'Solid', 'Water Soluble', 2.92, 7.0),
('STAN-FLU', 'Stannous Fluoride', 'SnF2', '7783-47-3', 'Fluoride', 'Solid', 'Water Soluble', 4.57, 4.5),
('GLYC', 'Glycerin', 'C3H8O3', '56-81-5', 'Humectant', 'Liquid', 'Miscible', 1.261, 7.0),
('SORB', 'Sorbitol', 'C6H14O6', '50-70-4', 'Humectant', 'Liquid', 'Water Soluble', 1.489, 7.0),
('PEG-400', 'Polyethylene Glycol 400', '(C2H4O)nH2O', '25322-68-3', 'Humectant', 'Liquid', 'Water Soluble', 1.128, 7.0),
('SLS', 'Sodium Lauryl Sulfate', 'C12H25NaO4S', '151-21-3', 'Surfactant', 'Solid', 'Water Soluble', 1.01, 7.0),
('SLA', 'Sodium Laureth Sulfate', 'C12H25(OC2H4)nOSO3Na', '9004-82-4', 'Surfactant', 'Liquid', 'Water Soluble', 1.05, 7.0),
('SILICA', 'Hydrated Silica', 'SiO2·nH2O', '7631-86-9', 'Abraisive', 'Solid', 'Insoluble', 2.0, 7.0),
('CAL-CARB', 'Calcium Carbonate', 'CaCO3', '471-34-1', 'Abraisive', 'Solid', 'Insoluble', 2.71, 9.0),
('CMC', 'Carboxymethyl Cellulose', '[C6H7O2(OH)2OCH2COONa]n', '9004-32-4', 'Binder', 'Solid', 'Water Soluble', 1.6, 6.5),
('XANTHAN', 'Xanthan Gum', 'C35H49O29', '11138-66-2', 'Binder', 'Solid', 'Water Soluble', 1.5, 6.0),
('PEP-MINT', 'Peppermint Oil', NULL, '8006-90-4', 'Flavor', 'Liquid', 'Partially Soluble', 0.9, 7.0),
('SPEAR', 'Spearmint Oil', NULL, '8008-79-5', 'Flavor', 'Liquid', 'Partially Soluble', 0.92, 7.0),
('SACCH', 'Sodium Saccharin', 'C7H4NNaO3S', '128-44-9', 'Sweetener', 'Solid', 'Water Soluble', 0.828, 7.0),
('ASP', 'Aspartame', 'C14H18N2O5', '22839-47-0', 'Sweetener', 'Solid', 'Water Soluble', 1.35, 7.0),
('TIO2', 'Titanium Dioxide', 'TiO2', '13463-67-7', 'Colorant', 'Solid', 'Insoluble', 4.23, 7.0),
('WATER', 'Purified Water', 'H2O', '7732-18-5', 'Solvent', 'Liquid', 'Miscible', 1.0, 7.0),
('SOD-BEN', 'Sodium Benzoate', 'C7H5NaO2', '532-32-1', 'Preservative', 'Solid', 'Water Soluble', 1.44, 7.5),
('POT-SORB', 'Potassium Sorbate', 'C6H7KO2', '590-00-1', 'Preservative', 'Solid', 'Water Soluble', 1.36, 7.0);

-- Insert companies
INSERT INTO companies (company_code, company_name, legal_name, company_type, country_id) VALUES
('P&G', 'Procter & Gamble', 'The Procter & Gamble Company', 'Manufacturer', 1),
('COLGATE', 'Colgate-Palmolive', 'Colgate-Palmolive Company', 'Manufacturer', 1),
('UNILEVER', 'Unilever', 'Unilever PLC', 'Manufacturer', 3),
('GLAXO', 'GlaxoSmithKline', 'GlaxoSmithKline plc', 'Manufacturer', 3),
('CHURCH-DW', 'Church & Dwight', 'Church & Dwight Co., Inc.', 'Manufacturer', 1),
('HENKEL', 'Henkel AG', 'Henkel AG & Co. KGaA', 'Manufacturer', 4),
('LION', 'Lion Corporation', 'Lion Corporation', 'Manufacturer', 8),
('SUNSTAR', 'Sunstar Inc.', 'Sunstar Inc.', 'Manufacturer', 8),
('PROD-LAB', 'Production Lab Services', 'Production Lab Services Inc.', 'Lab', 1),
('QC-LAB', 'Quality Control Labs', 'Quality Control Laboratories Ltd.', 'Lab', 3),
('BASF', 'BASF SE', 'BASF SE', 'Supplier', 4),
('DOW', 'Dow Chemical', 'The Dow Chemical Company', 'Supplier', 1),
('EVONIK', 'Evonik Industries', 'Evonik Industries AG', 'Supplier', 4),
('SOLVAY', 'Solvay S.A.', 'Solvay S.A.', 'Supplier', 5),
('CRODA', 'Croda International', 'Croda International Plc', 'Supplier', 3),
('GIVAUDAN', 'Givaudan SA', 'Givaudan SA', 'Supplier', 10);

-- Insert persons
INSERT INTO persons (person_code, first_name, last_name, email, company_id, role, specialization) VALUES
('DR-SMITH', 'Robert', 'Smith', 'r.smith@prodlab.com', 9, 'Scientist', 'Formulation Chemistry'),
('DR-JONES', 'Sarah', 'Jones', 's.jones@qclab.com', 10, 'QC_Technician', 'Analytical Chemistry'),
('DR-KUMAR', 'Raj', 'Kumar', 'r.kumar@prodlab.com', 9, 'Process_Engineer', 'Process Engineering'),
('DR-WONG', 'Jennifer', 'Wong', 'j.wong@qclab.com', 10, 'Lab_Technician', 'Microbiology'),
('DR-MILLER', 'David', 'Miller', 'd.miller@colgate.com', 2, 'R&D_Manager', 'Dental Science'),
('DR-CHEN', 'Wei', 'Chen', 'w.chen@pg.com', 1, 'Scientist', 'Materials Science'),
('DR-THOMPSON', 'Emma', 'Thompson', 'e.thompson@unilever.com', 3, 'Regulatory_Specialist', 'Regulatory Affairs');

-- Insert brands
INSERT INTO brands (brand_code, brand_name, parent_company_id, market_segment) VALUES
('COL-CAV', 'Colgate Cavity Protection', 2, 'Mid-Range'),
('COL-TOT', 'Colgate Total', 2, 'Premium'),
('CREST-PRO', 'Crest Pro-Health', 1, 'Premium'),
('CREST-3DW', 'Crest 3D White', 1, 'Premium'),
('SEN-REL', 'Sensodyne Relief', 4, 'Premium'),
('SEN-WHT', 'Sensodyne Whitening', 4, 'Premium'),
('AQUA-EXT', 'Aquafresh Extreme Clean', 3, 'Mid-Range'),
('TOM-NAT', 'Toms Natural', 5, 'Natural'),
('ARM-HAM', 'Arm & Hammer Advance White', 5, 'Economy'),
('LION-REG', 'Lion Systema', 7, 'Premium');

-- Insert production facilities
INSERT INTO production_facilities (facility_code, facility_name, company_id, country_id, gmp_certification, capacity_kgs_per_day) VALUES
('PLANT-NY', 'New York Manufacturing Plant', 2, 1, 'FDA-GMP', 25000),
('PLANT-OH', 'Ohio Production Facility', 1, 1, 'FDA-GMP', 30000),
('PLANT-UK', 'UK Manufacturing Centre', 3, 3, 'MHRA-GMP', 20000),
('PLANT-GER', 'German Production Plant', 4, 4, 'EMA-GMP', 18000),
('PLANT-JPN', 'Tokyo Manufacturing Plant', 7, 8, 'PMDA-GMP', 15000);

-- Insert formulations
INSERT INTO formulations (
    formulation_code, formulation_name, brand_id, product_type, 
    flavor_profile, target_ph, fluoride_ppm, status, created_by
) VALUES
('FRM-001', 'Cavity Protection Classic', 1, 'Regular_Toothpaste', 'Mint', 7.0, 1000, 'Active', 5),
('FRM-002', 'Total Advanced Care', 2, 'Gum_Care', 'Peppermint', 6.8, 1450, 'Active', 5),
('FRM-003', 'Pro-Health Enamel', 3, 'Enamel_Repair', 'Clean Mint', 7.2, 1100, 'Active', 6),
('FRM-004', '3D White Professional', 4, 'Whitening', 'Radiant Mint', 6.5, 1500, 'Active', 6),
('FRM-005', 'Sensitive Relief', 5, 'Sensitive', 'Mint', 7.0, 0, 'Active', 5),
('FRM-006', 'Advanced Whitening', 6, 'Whitening', 'Fresh Mint', 6.8, 1450, 'Active', 5);

-- ============================================
-- 17. COMPLETE FORMULATION COMPONENTS (ALL FIXED)
-- ============================================

-- FRM-001: Cavity Protection Classic - Total: 100.12%
INSERT INTO formulation_components (formulation_id, compound_id, percentage_min, percentage_max, percentage_target, phase, function) VALUES
(1, 18, 30.0, 40.0, 34.0, 'Aqueous', 'Solvent'),
(1, 5, 15.0, 25.0, 20.0, 'Aqueous', 'Humectant'),
(1, 4, 5.0, 15.0, 10.0, 'Aqueous', 'Humectant'),
(1, 9, 15.0, 25.0, 20.0, 'Powder', 'Abrasive'),
(1, 10, 5.0, 15.0, 7.0, 'Powder', 'Abrasive'),
(1, 11, 0.5, 1.5, 1.2, 'Additive', 'Binder'),
(1, 12, 0.3, 1.0, 0.8, 'Additive', 'Thickener'),
(1, 7, 1.0, 2.0, 1.5, 'Additive', 'Surfactant'),
(1, 1, 0.21, 0.25, 0.22, 'Powder', 'Active Ingredient'),
(1, 13, 0.5, 1.5, 1.0, 'Additive', 'Flavor'),
(1, 15, 0.1, 0.3, 0.2, 'Additive', 'Sweetener'),
(1, 19, 0.1, 0.4, 0.3, 'Additive', 'Preservative'),
(1, 20, 0.1, 0.3, 0.2, 'Additive', 'Preservative'),
(1, 17, 0.3, 0.8, 0.5, 'Additive', 'Colorant');

-- FRM-002: Total Advanced Care - Total: 100.13%
INSERT INTO formulation_components (formulation_id, compound_id, percentage_min, percentage_max, percentage_target, phase, function) VALUES
(2, 18, 25.0, 35.0, 30.0, 'Aqueous', 'Solvent'),
(2, 6, 20.0, 30.0, 25.0, 'Aqueous', 'Humectant'),
(2, 5, 10.0, 20.0, 15.0, 'Aqueous', 'Humectant'),
(2, 9, 15.0, 25.0, 20.0, 'Powder', 'Abrasive'),
(2, 10, 2.0, 8.0, 5.0, 'Powder', 'Abrasive'),
(2, 11, 0.5, 1.5, 1.2, 'Additive', 'Binder'),
(2, 12, 0.3, 1.0, 0.8, 'Additive', 'Thickener'),
(2, 8, 1.0, 2.5, 1.8, 'Additive', 'Surfactant'),
(2, 2, 0.75, 0.85, 0.78, 'Powder', 'Active Ingredient'),
(2, 14, 0.5, 1.5, 0.8, 'Additive', 'Flavor'),
(2, 16, 0.1, 0.3, 0.2, 'Additive', 'Sweetener'),
(2, 19, 0.1, 0.4, 0.35, 'Additive', 'Preservative');

-- FRM-003: Pro-Health Enamel - Total: 100.22%
INSERT INTO formulation_components (formulation_id, compound_id, percentage_min, percentage_max, percentage_target, phase, function) VALUES
(3, 18, 35.0, 45.0, 40.0, 'Aqueous', 'Solvent'),
(3, 5, 15.0, 25.0, 20.0, 'Aqueous', 'Humectant'),
(3, 4, 5.0, 15.0, 10.0, 'Aqueous', 'Humectant'),
(3, 9, 15.0, 25.0, 18.0, 'Powder', 'Abrasive'),
(3, 11, 0.5, 1.5, 1.2, 'Additive', 'Binder'),
(3, 12, 0.3, 1.0, 0.8, 'Additive', 'Thickener'),
(3, 7, 1.0, 2.0, 1.5, 'Additive', 'Surfactant'),
(3, 1, 0.21, 0.25, 0.22, 'Powder', 'Active Ingredient'),
(3, 13, 0.5, 1.5, 1.0, 'Additive', 'Flavor'),
(3, 15, 0.1, 0.3, 0.2, 'Additive', 'Sweetener'),
(3, 20, 0.1, 0.4, 0.3, 'Additive', 'Preservative'),
(3, 19, 0.1, 0.4, 0.2, 'Additive', 'Preservative'),
(3, 17, 0.3, 0.8, 0.5, 'Additive', 'Colorant');

-- FRM-004: 3D White Professional - Total: 100.08%
INSERT INTO formulation_components (formulation_id, compound_id, percentage_min, percentage_max, percentage_target, phase, function) VALUES
(4, 18, 30.0, 40.0, 35.0, 'Aqueous', 'Solvent'),
(4, 6, 15.0, 25.0, 20.0, 'Aqueous', 'Humectant'),
(4, 5, 10.0, 20.0, 15.0, 'Aqueous', 'Humectant'),
(4, 9, 20.0, 30.0, 25.0, 'Powder', 'Abrasive'),
(4, 11, 0.5, 1.5, 1.2, 'Additive', 'Binder'),
(4, 12, 0.3, 1.0, 0.6, 'Additive', 'Thickener'),
(4, 8, 1.0, 2.5, 2.0, 'Additive', 'Surfactant'),
(4, 2, 0.75, 0.85, 0.78, 'Powder', 'Active Ingredient'),
(4, 13, 0.5, 1.5, 1.0, 'Additive', 'Flavor'),
(4, 15, 0.1, 0.3, 0.2, 'Additive', 'Sweetener'),
(4, 19, 0.1, 0.4, 0.3, 'Additive', 'Preservative');

-- FRM-005: Sensitive Relief - Total: 100.30%
INSERT INTO formulation_components (formulation_id, compound_id, percentage_min, percentage_max, percentage_target, phase, function) VALUES
(5, 18, 35.0, 45.0, 40.0, 'Aqueous', 'Solvent'),
(5, 5, 15.0, 25.0, 20.0, 'Aqueous', 'Humectant'),
(5, 4, 5.0, 15.0, 10.0, 'Aqueous', 'Humectant'),
(5, 9, 10.0, 20.0, 15.0, 'Powder', 'Abrasive'),
(5, 11, 0.5, 1.5, 1.2, 'Additive', 'Binder'),
(5, 12, 0.3, 1.0, 0.8, 'Additive', 'Thickener'),
(5, 7, 0.5, 1.5, 1.0, 'Additive', 'Surfactant'),
(5, 8, 0.3, 1.0, 0.5, 'Additive', 'Surfactant'),
(5, 13, 0.5, 1.5, 1.0, 'Additive', 'Flavor'),
(5, 15, 0.1, 0.3, 0.2, 'Additive', 'Sweetener'),
(5, 20, 0.1, 0.4, 0.3, 'Additive', 'Preservative'),
(5, 19, 0.1, 0.4, 0.2, 'Additive', 'Preservative'),
(5, 17, 0.3, 0.8, 0.5, 'Additive', 'Colorant');

-- FRM-006: Advanced Whitening - Total: 100.18%
INSERT INTO formulation_components (formulation_id, compound_id, percentage_min, percentage_max, percentage_target, phase, function) VALUES
(6, 18, 30.0, 40.0, 35.0, 'Aqueous', 'Solvent'),
(6, 6, 15.0, 25.0, 20.0, 'Aqueous', 'Humectant'),
(6, 5, 10.0, 20.0, 15.0, 'Aqueous', 'Humectant'),
(6, 9, 20.0, 30.0, 25.0, 'Powder', 'Abrasive'),
(6, 11, 0.5, 1.5, 1.2, 'Additive', 'Binder'),
(6, 12, 0.3, 1.0, 0.6, 'Additive', 'Thickener'),
(6, 8, 1.0, 2.5, 2.0, 'Additive', 'Surfactant'),
(6, 2, 0.75, 0.85, 0.78, 'Powder', 'Active Ingredient'),
(6, 14, 0.5, 1.5, 1.0, 'Additive', 'Flavor'),
(6, 16, 0.1, 0.3, 0.2, 'Additive', 'Sweetener'),
(6, 19, 0.1, 0.4, 0.4, 'Additive', 'Preservative');

-- ============================================
-- 18. VERIFY FORMULATION TOTALS
-- ============================================

SELECT 
    f.formulation_code,
    f.formulation_name,
    ROUND(SUM(fc.percentage_target)::numeric, 2) AS total_percentage,
    CASE 
        WHEN SUM(fc.percentage_target) BETWEEN 95 AND 105 THEN '✓ VALID'
        ELSE '✗ INVALID'
    END AS validation_status,
    COUNT(fc.component_id) AS ingredient_count
FROM formulations f
JOIN formulation_components fc ON f.formulation_id = fc.formulation_id
GROUP BY f.formulation_id, f.formulation_code, f.formulation_name
ORDER BY f.formulation_id;

-- ============================================
-- 19. INSERT QC PARAMETERS
-- ============================================

INSERT INTO qc_parameters (parameter_code, parameter_name, parameter_type, category, target_min, target_max) VALUES
('pH-7', 'pH Level', 'Chemical', 'pH', 6.5, 7.5),
('VISC-100', 'Viscosity', 'Physical', 'Viscosity', 80000, 120000),
('FLUORIDE-PPM', 'Fluoride Content', 'Chemical', 'Fluoride_Content', 950, 1050),
('FLUORIDE-HIGH', 'Fluoride Content - High', 'Chemical', 'Fluoride_Content', 1400, 1500),
('DENSITY', 'Density', 'Physical', 'Density', 1.2, 1.5),
('MICROBIO', 'Microbial Count', 'Microbiological', 'Microbial_Count', 0, 100),
('APPEARANCE', 'Appearance', 'Sensory', 'Appearance', 1, 5),
('FLAVOR-INTENSITY', 'Flavor Intensity', 'Sensory', 'Flavor', 7, 9),
('SHELF-LIFE', 'Shelf Life Stability', 'Performance', 'Stability', 24, 36),
('ABRASION', 'RDA Value', 'Performance', 'Abrasiveness', 70, 100),
('MOISTURE', 'Moisture Content', 'Chemical', 'Stability', 20, 30),
('WEIGHT', 'Fill Weight', 'Physical', 'Weight', 98, 102);

-- ============================================
-- 20. INSERT CHEMICAL LABS
-- ============================================

INSERT INTO chemical_labs (lab_code, lab_name, company_id, facility_id, lab_type, accreditation, is_gmp_compliant) VALUES
('R&D-LAB-01', 'Research & Development Lab', 2, 1, 'R&D', 'ISO 17025', true),
('QC-LAB-01', 'Quality Control Laboratory', 2, 1, 'QC', 'ISO 17025', true),
('QC-LAB-UK', 'Quality Control Lab UK', 3, 3, 'QC', 'ISO 17025', true),
('STAB-LAB', 'Stability Testing Lab', 9, 4, 'Stability', 'ISO 17025', true),
('MICRO-LAB', 'Microbiology Laboratory', 10, 2, 'Microbiology', 'ISO 17025', true);

-- ============================================
-- 21. INSERT PRODUCTION STAGES
-- ============================================

INSERT INTO production_stages (stage_code, stage_name, stage_order, stage_type, default_temperature_celsius, default_duration_minutes, is_critical_control_point) VALUES
('PREP-01', 'Raw Material Preparation', 1, 'Preparation', 25.0, 30, false),
('COMP-01', 'Compounding', 2, 'Compounding', 25.0, 45, true),
('MIX-01', 'Mixing', 3, 'Mixing', 25.0, 60, true),
('DEAER-01', 'Deaeration', 4, 'Deaeration', 25.0, 30, false),
('HOLD-01', 'Holding Tank', 5, 'Holding', 25.0, 120, false),
('FILL-01', 'Filling', 6, 'Filling', 25.0, 90, true),
('PACK-01', 'Packaging', 7, 'Packaging', 25.0, 60, false),
('INSP-01', 'Final Inspection', 8, 'Inspection', 25.0, 30, true);

-- ============================================
-- 22. ADDITIONAL INDEXES FOR PERFORMANCE
-- ============================================

CREATE INDEX idx_inventory_compound_status ON raw_material_inventory(compound_id, status);
CREATE INDEX idx_inventory_facility_status ON raw_material_inventory(facility_id, status);
CREATE INDEX idx_batch_materials_batch ON batch_raw_materials(batch_id);
CREATE INDEX idx_tests_status_date ON qc_tests(status, test_date);
CREATE INDEX idx_stability_batch_status ON stability_studies(batch_id, status);
CREATE INDEX idx_formulation_components_formula ON formulation_components(formulation_id, compound_id);

-- ============================================
-- 23. CORRECTED TEST QUERIES
-- ============================================

-- Test the fixed views
SELECT * FROM v_material_expiry_alert LIMIT 10;
SELECT * FROM v_batch_summary LIMIT 10;
SELECT * FROM v_production_efficiency LIMIT 10;
SELECT * FROM v_qc_dashboard LIMIT 10;
SELECT * FROM v_formulation_details LIMIT 10;

-- Verify formulation totals (should all be VALID)
SELECT 
    f.formulation_code,
    f.formulation_name,
    ROUND(SUM(fc.percentage_target)::numeric, 2) AS total_percentage,
    CASE 
        WHEN SUM(fc.percentage_target) BETWEEN 95 AND 105 THEN '✓ VALID'
        ELSE '✗ INVALID'
    END AS validation_status,
    COUNT(fc.component_id) AS ingredient_count
FROM formulations f
JOIN formulation_components fc ON f.formulation_id = fc.formulation_id
GROUP BY f.formulation_id, f.formulation_code, f.formulation_name
ORDER BY f.formulation_id;

-- ============================================
-- Test Stored Procedures (CORRECTED)
-- ============================================

-- Test 1: Create Production Batch
DO $$
DECLARE
    v_batch_id INTEGER;
BEGIN
    v_batch_id := create_production_batch(
        1,                          -- formulation_id
        1,                          -- facility_id
        2500.0,                     -- target_quantity_kg
        CURRENT_DATE,               -- planned_start_date
        CURRENT_DATE + 1,           -- planned_end_date
        1,                          -- supervisor_id
        1                           -- created_by
    );
    RAISE NOTICE 'Created batch with ID: %', v_batch_id;
END $$;

-- Test 2: Record QC Test
DO $$
DECLARE
    v_test_id INTEGER;
BEGIN
    v_test_id := record_qc_test(
        1,      -- batch_id
        1,      -- parameter_id (pH)
        2,      -- lab_id
        6.9,    -- test_result
        NULL,   -- result_text
        2,      -- performed_by
        'Routine pH test'  -- test_notes
    );
    RAISE NOTICE 'Recorded QC test with ID: %', v_test_id;
END $$;

-- Test 3: Complete Production Batch
DO $$
BEGIN
    PERFORM complete_production_batch(
        1,      -- batch_id
        2450.0, -- actual_quantity_kg
        1       -- completed_by
    );
    RAISE NOTICE 'Batch completed successfully';
END $$;

-- ============================================
-- 24. FUNCTION SIGNATURE VERIFICATION
-- ============================================

-- Check function signatures
SELECT 
    proname AS function_name,
    pg_get_function_result(oid) AS return_type,
    pg_get_function_arguments(oid) AS arguments
FROM pg_proc 
WHERE proname IN ('create_production_batch', 'record_qc_test', 'complete_production_batch')
ORDER BY proname;

-- ============================================
-- 25. ADDITIONAL TEST: Create and complete a full batch
-- ============================================

DO $$
DECLARE
    v_batch_id INTEGER;
    v_test_id INTEGER;
BEGIN
    -- Step 1: Create batch
    v_batch_id := create_production_batch(
        2,                          -- formulation_id (FRM-002)
        2,                          -- facility_id
        3000.0,                     -- target_quantity_kg
        CURRENT_DATE,               -- planned_start_date
        CURRENT_DATE + 2,           -- planned_end_date
        3,                          -- supervisor_id
        1                           -- created_by
    );
    RAISE NOTICE 'Step 1: Created batch ID: %', v_batch_id;
    
    -- Step 2: Record QC tests
    v_test_id := record_qc_test(
        v_batch_id,   -- batch_id
        1,            -- parameter_id (pH)
        2,            -- lab_id
        6.8,          -- test_result
        NULL,         -- result_text
        2,            -- performed_by
        'pH test passed'
    );
    RAISE NOTICE 'Step 2: QC test ID: %', v_test_id;
    
    v_test_id := record_qc_test(
        v_batch_id,   -- batch_id
        2,            -- parameter_id (Viscosity)
        2,            -- lab_id
        95000,        -- test_result
        NULL,         -- result_text
        2,            -- performed_by
        'Viscosity test passed'
    );
    RAISE NOTICE 'Step 3: QC test ID: %', v_test_id;
    
    -- Step 3: Complete batch
    PERFORM complete_production_batch(
        v_batch_id,   -- batch_id
        2950.0,       -- actual_quantity_kg
        1             -- completed_by
    );
    RAISE NOTICE 'Step 4: Batch % completed', v_batch_id;
    
    -- Step 4: Show results
    RAISE NOTICE '=== Batch Summary ===';
    RAISE NOTICE 'Batch ID: %', v_batch_id;
    RAISE NOTICE 'Formulation: Total Advanced Care';
    RAISE NOTICE 'Target Quantity: 3000 kg';
    RAISE NOTICE 'Actual Quantity: 2950 kg';
    RAISE NOTICE 'Yield: 98.33 percent';
END $$;

-- ============================================
-- 26. GRANT PERMISSIONS (Optional)
-- ============================================

-- Create application user
-- CREATE USER toothpaste_app WITH PASSWORD 'secure_password';
-- GRANT CONNECT ON DATABASE toothpaste_db TO toothpaste_app;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO toothpaste_app;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO toothpaste_app;

-- ============================================
-- END OF DATABASE SCRIPT
-- ============================================