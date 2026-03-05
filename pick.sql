CREATE TABLE IF NOT EXISTS toothpastes (
    id INTEGER,
    brand_string TEXT,
	tube_mass_g INTEGER,
	rating INTEGER
);

INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (0,'Toothpaste 1', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (1,'Toothpaste 2', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (2,'Toothpaste 3', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (3,'Toothpaste 4', 100, 100);
INSERT INTO toothpastes (id, brand_string, tube_mass_g,rating) VALUES (4,'Nothing', 0, 0);

SELECT * FROM toothpastes WHERE id=mod((SELECT CAST(unixepoch('now') / 86400 AS INTEGER)), (SELECT COUNT(*) FROM toothpastes));
SELECT rating FROM toothpastes ORDER BY rating DESC LIMIT 1;
SELECT tube_mass_g FROM toothpastes ORDER BY tube_mass_g DESC LIMIT 1;