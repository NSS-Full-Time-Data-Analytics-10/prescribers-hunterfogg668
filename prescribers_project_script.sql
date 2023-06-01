SELECT * FROM prescriber;
SELECT * FROM prescription;
SELECT * FROM drug;
SELECT * FROM population;
SELECT * FROM cbsa;

SELECT DISTINCT * FROM cbsa
WHERE fipscounty = '53077';

--Q1A most claims

SELECT npi, SUM(total_claim_count)
FROM prescription
GROUP BY npi
ORDER BY SUM(total_claim_count) DESC
LIMIT 1;

--Q1B include name

SELECT prescriber.nppes_provider_first_name,
		prescriber.nppes_provider_last_org_name,
		prescriber.specialty_description,
		SUM(prescription.total_claim_count)
	FROM prescription
LEFT JOIN prescriber
	ON prescription.npi = prescriber.npi
GROUP BY prescriber.nppes_provider_first_name, 
			prescriber.nppes_provider_last_org_name,
			prescriber.specialty_description
ORDER BY SUM(total_claim_count) DESC
LIMIT 1;

--Q2A highest claims by practice

SELECT prescriber.specialty_description,
		SUM(total_claim_count)
	FROM prescriber
LEFT JOIN prescription 
	ON prescriber.npi = prescription.npi
GROUP BY prescriber.specialty_description
ORDER BY SUM(total_claim_count) DESC NULLS LAST;

--Q2B highest claims by practice for opiods

SELECT prescriber.specialty_description,
		SUM(total_claim_count) AS total_opioid_claims
	FROM prescriber
INNER JOIN prescription 
	ON prescriber.npi = prescription.npi
INNER JOIN drug
	ON drug.drug_name = prescription.drug_name
WHERE opioid_drug_flag = 'Y'
GROUP BY prescriber.specialty_description
ORDER BY total_opioid_claims DESC;

--Q2C

SELECT prescriber.specialty_description,
		SUM(total_claim_count) AS total_claims
	FROM prescriber
LEFT JOIN prescription 
	ON prescriber.npi = prescription.npi
GROUP BY prescriber.specialty_description
	HAVING SUM(total_claim_count) IS NULL;
	
--Q2D DIFFICULT BONUS
---query that finds total claim count
SELECT specialty_description, 
		(opioids.opioid_count/SUM(total_claim_count)*100) AS opioid_percentage
		FROM prescription AS total_count_of_claims
	INNER JOIN drug USING(drug_name)
	INNER JOIN prescriber USING(npi)
---join with subquery that finds opioid count
 	INNER JOIN (SELECT specialty_description, SUM(total_claim_count) AS opioid_count
					FROM prescription AS opioids
						INNER JOIN drug USING(drug_name)
						INNER JOIN prescriber USING(npi)
					WHERE opioid_drug_flag = 'Y'
					GROUP BY specialty_description 
					ORDER BY opioid_count DESC) AS opioids
		USING(specialty_description)
GROUP BY specialty_description, opioids.opioid_count
ORDER BY opioid_percentage DESC;

--Q3A drug generic_name w/ highest total drug cost

SELECT drug.generic_name,
		SUM(prescription.total_drug_cost::MONEY) AS total_cost
		FROM drug
INNER JOIN prescription
	ON drug.drug_name = prescription.drug_name
GROUP BY drug.generic_name
ORDER BY total_cost DESC;

--Q3B drug generic_name w/ highest total drug cost per day

SELECT drug.generic_name,
		ROUND(SUM(prescription.total_drug_cost)/SUM(prescription.total_day_supply), 2) AS cost_per_day
		FROM drug
INNER JOIN prescription
	ON drug.drug_name = prescription.drug_name
GROUP BY drug.generic_name
ORDER BY cost_per_day DESC;

--Q4A USE CASE WHEN

SELECT drug_name,
		(CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'
			WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
			ELSE 'neither' END) AS drug_type
FROM drug;

--Q4B
--with subquery
SELECT drug_types.drug_type, drug_types.total_cost
FROM
(SELECT	(CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'   ----------case table to sum by drug type
			WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
			ELSE 'neither' END) AS drug_type,
		SUM(total_drug_cost::MONEY) AS total_cost
FROM drug
INNER JOIN prescription
	USING (drug_name)
GROUP BY drug_type) AS drug_types
WHERE drug_type = 'opioid'                   ------------remove 'neither'
	OR drug_type = 'antibiotic'
ORDER BY total_cost DESC;

--with CTE
WITH drug_types AS (SELECT	(CASE WHEN opioid_drug_flag = 'Y' THEN 'opioid'   ----------case table to sum by drug type
					WHEN antibiotic_drug_flag = 'Y' THEN 'antibiotic'
					ELSE 'neither' END) AS drug_type,
					SUM(total_drug_cost::MONEY) AS total_cost
					FROM drug
					INNER JOIN prescription
					USING (drug_name)
					GROUP BY drug_type)
SELECT * FROM drug_types
WHERE drug_type = 'opioid' OR drug_type = 'antibiotic'
ORDER BY total_cost DESC;

--Q5A CBSAs in TN

SELECT COUNT (DISTINCT cbsa) FROM cbsa
INNER JOIN fips_county
	USING(fipscounty)
WHERE state = 'TN';

--Q5B CBSA w/ largest county
--Whole list
SELECT cbsa, cbsaname, SUM(population)
	FROM cbsa
INNER JOIN population
	USING(fipscounty)
GROUP BY cbsa, cbsaname
ORDER BY sum DESC;

---top and bottom with UNION
(SELECT cbsa, cbsaname, SUM(population)
	FROM cbsa
INNER JOIN population
	USING(fipscounty)
GROUP BY cbsa, cbsaname
ORDER BY sum ASC
LIMIT 1)
UNION
(SELECT cbsa, cbsaname, SUM(population)
	FROM cbsa
INNER JOIN population
	USING(fipscounty)
GROUP BY cbsa, cbsaname
ORDER BY sum DESC
LIMIT 1);

--Q5C largest county not included in a cbsa

SELECT fips_county.county, population 
	FROM population
LEFT JOIN cbsa
	USING (fipscounty)
INNER JOIN fips_county
	USING(fipscounty)
WHERE cbsa IS NULL
ORDER BY population DESC;

--Q6A total claims > 3k

SELECT drug_name, total_claim_count
	FROM prescription
WHERE total_claim_count > 3000;

--Q6B add column for opioid

SELECT drug_name, 
		total_claim_count,
		opioid_drug_flag
	FROM prescription
INNER JOIN drug
	USING(drug_name)
WHERE total_claim_count > 3000;

--Q6C add prescriber first and last name

SELECT (nppes_provider_first_name || ' ' || nppes_provider_last_org_name) AS full_name,
		drug_name, 
		total_claim_count,
		opioid_drug_flag
	FROM prescription
INNER JOIN drug
	USING(drug_name)
INNER JOIN prescriber
	ON(prescription.npi = prescriber.npi)
WHERE total_claim_count > 3000
ORDER BY total_claim_count DESC;

--Q7A

SELECT npi, drug_name FROM prescriber
	CROSS JOIN drug
WHERE specialty_description = 'Pain Management'
	AND nppes_provider_city ILIKE 'Nashville'
	AND opioid_drug_flag = 'Y';
	
--Q7B

SELECT npi, drug.drug_name, SUM(total_claim_count) AS total_claims FROM prescriber
	CROSS JOIN drug
	LEFT JOIN prescription USING(npi, drug_name)
WHERE specialty_description = 'Pain Management'
	AND nppes_provider_city ILIKE 'Nashville'
	AND opioid_drug_flag = 'Y'
GROUP BY npi, drug.drug_name
ORDER BY total_claims DESC NULLS LAST;

--Q7C

SELECT npi, drug.drug_name, COALESCE(SUM(total_claim_count), 0) AS total_claims FROM prescriber
	CROSS JOIN drug
	LEFT JOIN prescription USING(npi, drug_name)
WHERE specialty_description = 'Pain Management'
	AND nppes_provider_city ILIKE 'Nashville'
	AND opioid_drug_flag = 'Y'
GROUP BY npi, drug.drug_name
ORDER BY total_claims DESC;


---BONUS
---BONUS
---BONUS
---BONUS
---BONUS

---B1

SELECT COUNT(*)
	FROM 	((SELECT DISTINCT npi FROM prescriber)
			EXCEPT
			(SELECT DISTINCT npi FROM prescription)) AS npis

---B2
--A top 5 drugs for Family Practice

SELECT generic_name, SUM(total_claim_count) AS claim_count FROM drug
INNER JOIN prescription
	USING(drug_name)
INNER JOIN prescriber
	USING(npi)
WHERE specialty_description = 'Family Practice'
GROUP BY generic_name
ORDER BY claim_count DESC
LIMIT 5;

--B top 5 drugs for Cardiology

SELECT generic_name, SUM(total_claim_count) AS claim_count FROM drug
INNER JOIN prescription
	USING(drug_name)
INNER JOIN prescriber
	USING(npi)
WHERE specialty_description = 'Cardiology'
GROUP BY generic_name
ORDER BY claim_count DESC
LIMIT 5;

--C combine to find the drugs in common
--use intersect to find generic names that are in top 5 of both Familty practice and Cardiology by total claim count
(SELECT generic_name FROM drug
INNER JOIN prescription
	USING(drug_name)
INNER JOIN prescriber
	USING(npi)
WHERE specialty_description = 'Family Practice'
GROUP BY generic_name
ORDER BY SUM(total_claim_count) DESC
LIMIT 5)
INTERSECT
(SELECT generic_name FROM drug
INNER JOIN prescription
	USING(drug_name)
INNER JOIN prescriber
	USING(npi)
WHERE specialty_description = 'Cardiology'
GROUP BY generic_name
ORDER BY SUM(total_claim_count) DESC
LIMIT 5);

SELECT * FROM prescriber;
SELECT * FROM prescription;

---B3
--A top five for Nash
SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
	FROM prescriber
INNER JOIN prescription
	USING(npi)
WHERE nppes_provider_city ILIKE 'NASHVILLE'
GROUP BY npi, nppes_provider_city
ORDER BY SUM(total_claim_count) DESC
LIMIT 5;

--B top five for memphis
SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city
	FROM prescriber
INNER JOIN prescription
	USING(npi)
WHERE nppes_provider_city ILIKE 'MEMPHIS'
GROUP BY npi, nppes_provider_city
ORDER BY SUM(total_claim_count) DESC
LIMIT 5;

--C top five of nash, mem, chatt, knox

(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city  ------ top 5 nash
	FROM prescriber
INNER JOIN prescription
	USING(npi)
WHERE nppes_provider_city ILIKE 'NASHVILLE'
GROUP BY npi, nppes_provider_city
ORDER BY SUM(total_claim_count) DESC
LIMIT 5)
UNION
(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city  ------ top 5 mem
	FROM prescriber
INNER JOIN prescription
	USING(npi)
WHERE nppes_provider_city ILIKE 'MEMPHIS'
GROUP BY npi, nppes_provider_city
ORDER BY SUM(total_claim_count) DESC
LIMIT 5)
UNION
(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city  ------ top 5 knox
	FROM prescriber
INNER JOIN prescription
	USING(npi)
WHERE nppes_provider_city ILIKE 'KNOXVILLE'
GROUP BY npi, nppes_provider_city
ORDER BY SUM(total_claim_count) DESC
LIMIT 5)
UNION
(SELECT npi, SUM(total_claim_count) AS total_claims, nppes_provider_city  ------ top 5 chatt
	FROM prescriber
INNER JOIN prescription
	USING(npi)
WHERE nppes_provider_city ILIKE 'CHATTANOOGA'
GROUP BY npi, nppes_provider_city
ORDER BY SUM(total_claim_count) DESC
LIMIT 5)	
ORDER BY total_claims DESC;


---B4	

SELECT county,overdose_deaths, year FROM overdose_deaths
INNER JOIN fips_county
ON fips_county.fipscounty::INTEGER = overdose_deaths.fipscounty
WHERE overdose_deaths > (SELECT AVG(overdose_deaths) FROM overdose_deaths)
ORDER BY overdose_deaths DESC;

---B5
--A
---subquery
SELECT SUM(population) FROM fips_county
INNER JOIN population
	USING(fipscounty)
WHERE state = 'TN'

--B
WITH tn_pop AS (SELECT SUM(population) AS total_tn_pop FROM fips_county
				INNER JOIN population
				USING(fipscounty)
				WHERE state = 'TN')
SELECT county, ROUND((population/total_tn_pop)*100,2) AS percent_of_tn FROM fips_county
INNER JOIN population
USING(fipscounty)
CROSS JOIN tn_pop
ORDER BY percent_of_tn DESC;





SELECT * FROM population
SELECT * FROM fips_county
















