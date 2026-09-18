-- Seed the AEO registry with Citrus Connect (UK B2B sales recruitment).
-- Lifted from vertical_insights reports/ci_pipeline/config/citrus_connect_vs_aaronwallis.yaml.
-- Idempotent. Requires the backend migration (combined .../002_aeo_schema.sql).

INSERT INTO aeo.client
    (client_id, name, domain, aliases, subject_pattern, vertical, country, engines,
     competitors, prompts, cadence, active, notes)
VALUES (
    'citrus_connect',
    'Citrus Connect',
    'citrus-connect.co.uk',
    ARRAY['Citrus Connect','Citrus Connect Recruitment','Citrus Recruitment'],
    'citrus\s?connect',
    'sales_recruitment',
    'GB',
    ARRAY['chatgpt','perplexity','google_ai'],
    jsonb_build_array(
        jsonb_build_object('name','Aaron Wallis','pattern','aaron\s?wallis','domain','aaronwallis.co.uk'),
        jsonb_build_object('name','Pareto','pattern','\bpareto\b','domain','pareto.co.uk'),
        jsonb_build_object('name','BMS Performance','pattern','bms\s?performance|\bBMS\b','domain',''),
        jsonb_build_object('name','Robert Half','pattern','robert\s?half','domain',''),
        jsonb_build_object('name','Michael Page','pattern','michael\s?page','domain',''),
        jsonb_build_object('name','Hays','pattern','\bhays\b','domain',''),
        jsonb_build_object('name','Reed','pattern','\breed\b','domain',''),
        jsonb_build_object('name','Rider Levett','pattern','rider\s?levett','domain',''),
        jsonb_build_object('name','Celsius Graduate','pattern','celsius','domain',''),
        jsonb_build_object('name','Sales Talent','pattern','sales\s?talent','domain','')
    ),
    jsonb_build_array(
        jsonb_build_object('text','Best sales recruitment agency UK','branded',false),
        jsonb_build_object('text','Best B2B sales recruitment agency UK','branded',false),
        jsonb_build_object('text','How to recruit a field sales team UK','branded',false),
        jsonb_build_object('text','Best agency to hire direct sales staff UK','branded',false),
        jsonb_build_object('text','Best sales recruiters Leeds','branded',false),
        jsonb_build_object('text','Specialist sales recruitment agency UK','branded',false),
        jsonb_build_object('text','How to hire telesales staff UK agency','branded',false),
        jsonb_build_object('text','Sales interview questions to ask candidates','branded',false),
        jsonb_build_object('text','Citrus Connect Recruitment reviews','branded',true),
        jsonb_build_object('text','Aaron Wallis Sales Recruitment reviews','branded',true)
    ),
    'weekly',
    true,
    'Leeds direct-sales recruitment specialist. AI-invisible (0) vs Aaron Wallis content moat; discovery channel open. Competitor Aaron Wallis is national + content-led; Pareto also tracked.'
)
ON CONFLICT (client_id) DO UPDATE SET
    name=EXCLUDED.name, domain=EXCLUDED.domain, aliases=EXCLUDED.aliases,
    subject_pattern=EXCLUDED.subject_pattern, vertical=EXCLUDED.vertical, country=EXCLUDED.country,
    engines=EXCLUDED.engines, competitors=EXCLUDED.competitors, prompts=EXCLUDED.prompts,
    cadence=EXCLUDED.cadence, active=EXCLUDED.active, notes=EXCLUDED.notes, updated_at=now();
