CREATE TABLE artist (
    artist_id INTEGER PRIMARY KEY,
    name VARCHAR(120)
);

CREATE TABLE genre (
    genre_id INTEGER PRIMARY KEY,
    name VARCHAR(120)
);

CREATE TABLE media_type (
    media_type_id INTEGER PRIMARY KEY,
    name VARCHAR(120)
);

CREATE TABLE playlist (
    playlist_id INTEGER PRIMARY KEY,
    name VARCHAR(120)
);

CREATE TABLE employee (
    employee_id INTEGER PRIMARY KEY,
    last_name VARCHAR(20) NOT NULL,
    first_name VARCHAR(20) NOT NULL,
    title VARCHAR(30),
    reports_to INTEGER,
    birthdate DATETIME,
    hire_date DATETIME,
    address VARCHAR(70),
    city VARCHAR(40),
    state VARCHAR(40),
    country VARCHAR(40),
    postal_code VARCHAR(10),
    phone VARCHAR(24),
    fax VARCHAR(24),
    email VARCHAR(60),
    FOREIGN KEY (reports_to) REFERENCES employee(employee_id)
);


CREATE TABLE album (
    album_id INTEGER PRIMARY KEY,
    title VARCHAR(160) NOT NULL,
    artist_id INTEGER NOT NULL,
    FOREIGN KEY (artist_id) REFERENCES artist(artist_id)
);

CREATE TABLE customer (
    customer_id INTEGER PRIMARY KEY,
    first_name VARCHAR(40) NOT NULL,
    last_name VARCHAR(20) NOT NULL,
    company VARCHAR(80),
    address VARCHAR(70),
    city VARCHAR(40),
    state VARCHAR(40),
    country VARCHAR(40),
    postal_code VARCHAR(10),
    phone VARCHAR(24),
    fax VARCHAR(24),
    email VARCHAR(60) NOT NULL,
    support_rep_id INTEGER,
    FOREIGN KEY (support_rep_id) REFERENCES employee(employee_id)
);


CREATE TABLE track (
    track_id INTEGER PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    album_id INTEGER,
    media_type_id INTEGER NOT NULL,
    genre_id INTEGER,
    composer VARCHAR(220),
    milliseconds INTEGER NOT NULL,
    bytes INTEGER,
    unit_price NUMERIC(10,2) NOT NULL,
    FOREIGN KEY (album_id) REFERENCES album(album_id),
    FOREIGN KEY (genre_id) REFERENCES genre(genre_id),
    FOREIGN KEY (media_type_id) REFERENCES media_type(media_type_id)
);


CREATE TABLE invoice (
    invoice_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    invoice_date DATETIME NOT NULL,
    billing_address VARCHAR(70),
    billing_city VARCHAR(40),
    billing_state VARCHAR(40),
    billing_country VARCHAR(40),
    billing_postal_code VARCHAR(10),
    total NUMERIC(10,2) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customer(customer_id)
);

CREATE TABLE invoice_line (
    invoice_line_id INTEGER PRIMARY KEY,
    invoice_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    quantity INTEGER NOT NULL,
    FOREIGN KEY (invoice_id) REFERENCES invoice(invoice_id),
    FOREIGN KEY (track_id) REFERENCES track(track_id)
);

CREATE TABLE playlist_track (
    playlist_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    PRIMARY KEY (playlist_id, track_id),
    FOREIGN KEY (playlist_id) REFERENCES playlist(playlist_id),
    FOREIGN KEY (track_id) REFERENCES track(track_id)
);


-- CUSTOMER ANALYSIS
--1. Which customers have spent the most money?

SELECT 
    c.first_name, 
    c.last_name, 
    SUM(i.total) AS total_spent
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 5;


--2. What is the average customer lifetime value (CLV)?
-- Calculate the average of the total spending per customer
WITH customer_totals AS (
    SELECT customer_id, SUM(total) as total_spent
    FROM invoice
    GROUP BY customer_id
)
SELECT AVG(total_spent) as average_lifetime_value
FROM customer_totals;


--3. Repeat Purchases vs. One-Time Purchases
WITH purchase_counts AS (
    SELECT 
        customer_id, 
        COUNT(invoice_id) as invoice_count
    FROM invoice
    GROUP BY customer_id
)
SELECT 
    CASE 
        WHEN invoice_count = 1 THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END as customer_category,
    COUNT(customer_id) as customer_count
FROM purchase_counts
GROUP BY customer_category;

--4. Which country generates the most revenue per customer?
SELECT 
    c.country, 
    SUM(i.total) / COUNT(DISTINCT c.customer_id) as revenue_per_customer
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.country
ORDER BY revenue_per_customer DESC
LIMIT 5;

--5. Which customers haven't made a purchase in the last 6 months?
SELECT 
    c.first_name, 
    c.last_name, 
    c.email,
    MAX(i.invoice_date) as last_purchase_date
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id
HAVING last_purchase_date < DATE((SELECT MAX(invoice_date) FROM invoice), '-6 months');

--SALES AND REVENUE ANALYSIS



--1. What are the monthly revenue trends for the last two years?
WITH MonthlyRevenue AS (
    -- Step 1: Aggregate revenue by month for the last 2 years
    SELECT 
        DATE_TRUNC('month', invoice_date) AS sales_month,
        SUM(total) AS revenue
    FROM invoice
    WHERE invoice_date >= (SELECT MAX(invoice_date) FROM invoice) - INTERVAL '2 years'
    GROUP BY DATE_TRUNC('month', invoice_date)
)
-- Step 2: Use LAG() to look at the previous row and calculate Month-over-Month (MoM) growth
SELECT 
    sales_month,
    revenue,
    LAG(revenue) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(((revenue - LAG(revenue) OVER (ORDER BY sales_month)) / 
           LAG(revenue) OVER (ORDER BY sales_month)) * 100, 2) AS mom_growth_percentage
FROM MonthlyRevenue
ORDER BY sales_month;


--2. What is the average value of an invoice (purchase)?

WITH InvoiceStats AS (
    -- Step 1: Calculate the overall store average alongside every individual invoice
    SELECT 
        invoice_id,
        total AS invoice_total,
        AVG(total) OVER () AS overall_avg_invoice
    FROM invoice
),
SegmentedInvoices AS (
    -- Step 2: Segment the purchases based on how they compare to the average
    SELECT 
        invoice_id,
        invoice_total,
        CASE 
            WHEN invoice_total > (overall_avg_invoice * 1.5) THEN 'High Value Purchase'
            WHEN invoice_total < (overall_avg_invoice * 0.5) THEN 'Low Value Purchase'
            ELSE 'Average Value Purchase'
        END AS purchase_segment
    FROM InvoiceStats
)
-- Step 3: Summarize the segments
SELECT 
    purchase_segment,
    COUNT(invoice_id) AS number_of_invoices,
    ROUND(AVG(invoice_total), 2) AS segment_average_value
FROM SegmentedInvoices
GROUP BY purchase_segment
ORDER BY segment_average_value DESC;


--3. Which payment methods are used most frequently?

WITH PaymentFrequency AS (
    SELECT 
        payment_method,
        COUNT(invoice_id) AS times_used,
        SUM(total) AS total_revenue_processed
    FROM invoice
    GROUP BY payment_method
)
SELECT 
    payment_method,
    times_used,
    total_revenue_processed,
    DENSE_RANK() OVER (ORDER BY times_used DESC) AS popularity_rank
FROM PaymentFrequency;


--4. How much revenue does each sales rep contribute? (Rank & % Contribution

WITH RepSales AS (
    SELECT 
        e.employee_id,
        e.first_name || ' ' || e.last_name AS sales_rep,
        SUM(i.total) AS total_revenue
    FROM employee e
    JOIN customer c ON e.employee_id = c.support_rep_id
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY e.employee_id, e.first_name, e.last_name
)
SELECT 
    sales_rep,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS sales_rank,
    ROUND((total_revenue / SUM(total_revenue) OVER ()) * 100, 2) AS percent_of_company_revenue
FROM RepSales
ORDER BY sales_rank;

--5. Which quarters have peak music sales? (Ranked Per Year)

WITH QuarterlySales AS (
    -- Step 1: Aggregate revenue by Year and Quarter
    SELECT 
        EXTRACT(YEAR FROM invoice_date) AS sales_year,
        EXTRACT(QUARTER FROM invoice_date) AS sales_quarter,
        SUM(total) AS revenue
    FROM invoice
    GROUP BY EXTRACT(YEAR FROM invoice_date), EXTRACT(QUARTER FROM invoice_date)
),
RankedQuarters AS (
    -- Step 2: Rank the quarters WITHIN each year
    SELECT 
        sales_year,
        sales_quarter,
        revenue,
        RANK() OVER (PARTITION BY sales_year ORDER BY revenue DESC) AS rank_in_year
    FROM QuarterlySales
)
-- Step 3: Filter to show only the #1 peak quarter for every year
SELECT * FROM RankedQuarters 
WHERE rank_in_year = 1 
ORDER BY sales_year;


--PRODUCT AND CONTENT ANALYSIS

-- QUESTION 1. Which tracks generated the most revenue? (Ranked by Sales Performance)


WITH TrackRevenue AS (
    SELECT 
        t.track_id,
        t.name AS track_name,
        SUM(il.unit_price * il.quantity) AS total_revenue
    FROM track t
    JOIN invoice_line il ON t.track_id = il.track_id
    GROUP BY t.track_id, t.name
)
SELECT 
    track_name,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank
FROM TrackRevenue
ORDER BY revenue_rank
LIMIT 10;

-- QUESTION 2. Which albums or playlists are most frequently included in purchases?

WITH AlbumSales AS (
    SELECT 
        al.title AS album_title,
        ar.name AS artist_name,
        COUNT(il.invoice_line_id) AS tracks_purchased
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist ar ON al.artist_id = ar.artist_id
    GROUP BY al.album_id, al.title, ar.name
)
SELECT 
    album_title,
    artist_name,
    tracks_purchased,
    DENSE_RANK() OVER (ORDER BY tracks_purchased DESC) AS popularity_rank
FROM AlbumSales
ORDER BY popularity_rank
LIMIT 5;

-- QUESTION 3. Are there any tracks or albums that have never been purchased?


SELECT 
    track_id,
    name AS unsold_track_name,
    unit_price
FROM track
WHERE track_id NOT IN (
    SELECT DISTINCT track_id FROM invoice_line
);

-- Albums never purchased:

SELECT 
    al.title AS unsold_album,
    ar.name AS artist_name
FROM album al
JOIN artist ar ON al.artist_id = ar.artist_id
WHERE al.album_id NOT IN (
    -- Subquery: Get all album IDs that have at least one sold track
    SELECT DISTINCT t.album_id 
    FROM track t
    JOIN invoice_line il ON t.track_id = il.track_id
);

-- QUESTION 4. What is the average price per track across different genres?

SELECT 
    g.name AS genre,
    ROUND(AVG(t.unit_price), 2) AS avg_track_price,
    ROUND(AVG(AVG(t.unit_price)) OVER (), 2) AS store_avg_price,
    CASE 
        WHEN AVG(t.unit_price) > AVG(AVG(t.unit_price)) OVER () THEN 'Above Store Average'
        ELSE 'Below Store Average'
    END AS price_category
FROM track t
JOIN genre g ON t.genre_id = g.genre_id
GROUP BY g.name
ORDER BY avg_track_price DESC;

-- QUESTION 5. How many tracks does the store have per genre and how does it correlate with sales?

WITH GenreInventory AS (
    -- CTE 1: Count total tracks available per genre
    SELECT 
        genre_id,
        COUNT(track_id) AS total_available_tracks
    FROM track
    GROUP BY genre_id
),
GenreSales AS (
    -- CTE 2: Count total tracks sold per genre
    SELECT 
        t.genre_id,
        COUNT(il.invoice_line_id) AS total_tracks_sold
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    GROUP BY t.genre_id
)
SELECT 
    g.name AS genre,
    i.total_available_tracks,
    COALESCE(s.total_tracks_sold, 0) AS total_tracks_sold,
    ROUND((s.total_tracks_sold::numeric / i.total_available_tracks), 2) AS sales_per_track_ratio,
    CASE 
        WHEN (s.total_tracks_sold::numeric / i.total_available_tracks) >= 1.5 THEN 'High Demand (Restock/Promote)'
        WHEN (s.total_tracks_sold::numeric / i.total_available_tracks) BETWEEN 0.5 AND 1.49 THEN 'Moderate Demand'
        ELSE 'Low Demand (Dead Inventory)'
    END AS performance_segment
FROM GenreInventory i
LEFT JOIN GenreSales s ON i.genre_id = s.genre_id
JOIN genre g ON i.genre_id = g.genre_id
ORDER BY total_tracks_sold DESC;


--ARTIST AND GENRE PERFORMANCE

-- QUESTION 1. Who are the top 5 highest-grossing artists?

SELECT 
    ar.name AS artist_name,
    SUM(il.unit_price * il.quantity) AS total_revenue
FROM invoice_line il
JOIN track t ON il.track_id = t.track_id
JOIN album al ON t.album_id = al.album_id
JOIN artist ar ON al.artist_id = ar.artist_id
GROUP BY ar.artist_id, ar.name
ORDER BY total_revenue DESC
LIMIT 5;

-- QUESTION 2. Which music genres are most popular in terms of tracks sold and total revenue?

WITH GenrePerformance AS (
    SELECT 
        g.name AS genre_name,
        SUM(il.quantity) AS tracks_sold,
        SUM(il.unit_price * il.quantity) AS total_revenue
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    GROUP BY g.genre_id, g.name
)
SELECT 
    genre_name,
    tracks_sold,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
    RANK() OVER (ORDER BY tracks_sold DESC) AS sales_volume_rank
FROM GenrePerformance
ORDER BY revenue_rank;

-- QUESTION 3. Are certain genres more popular in specific countries? (Geographic Segmentation)

WITH CountryGenreSales AS (
    -- Step 1: Calculate the total sales for every genre, separated by country
    SELECT 
        c.country,
        g.name AS genre_name,
        SUM(il.quantity) AS tracks_sold,
        SUM(il.unit_price * il.quantity) AS total_revenue
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
    GROUP BY c.country, g.genre_id, g.name
),
RankedCountryGenres AS (
    -- Step 2: Rank the genres WITHIN each country (Partitioning)
    SELECT 
        country,
        genre_name,
        tracks_sold,
        total_revenue,
        RANK() OVER (PARTITION BY country ORDER BY tracks_sold DESC) AS popularity_rank_in_country
    FROM CountryGenreSales
)
-- Step 3: Filter the results to only show the #1 most popular genre for each country
SELECT 
    country, 
    genre_name AS top_genre, 
    tracks_sold, 
    total_revenue
FROM RankedCountryGenres
WHERE popularity_rank_in_country = 1
ORDER BY tracks_sold DESC;


-- EMPLOYEE AND OPERATIONAL EFFICIENCY

--QUESTION 1. Which employees (support representatives) are managing the highest-spending customers?
WITH CustomerSpend AS (
    -- Step 1: Calculate lifetime spend per customer
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.support_rep_id,
        SUM(i.total) AS lifetime_spend
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.support_rep_id
),
RankedCustomers AS (
    -- Step 2: Rank the customers by spending
    SELECT 
        cs.customer_name,
        cs.lifetime_spend,
        e.first_name || ' ' || e.last_name AS support_representative,
        DENSE_RANK() OVER (ORDER BY cs.lifetime_spend DESC) AS spending_rank
    FROM CustomerSpend cs
    JOIN employee e ON cs.support_rep_id = e.employee_id
)
-- Step 3: Show the top 5 highest spenders and their reps
SELECT * FROM RankedCustomers
WHERE spending_rank <= 5;




-- QUESTION 2. What is the average number of customers per employee?

SELECT 
    COUNT(customer_id) AS total_customers,
    COUNT(DISTINCT support_rep_id) AS total_support_reps,
    ROUND(
        COUNT(customer_id)::numeric / COUNT(DISTINCT support_rep_id), 
    2) AS avg_customers_per_employee
FROM customer;


-- QUESTION 3. Which employee regions bring in the most revenue?


WITH EmployeeRegionRevenue AS (
    -- Step 1: Aggregate revenue based on where the EMPLOYEE is located
    SELECT 
        e.city AS employee_city,
        e.state AS employee_state,
        e.country AS employee_country,
        SUM(i.total) AS region_revenue
    FROM employee e
    JOIN customer c ON e.employee_id = c.support_rep_id
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY e.city, e.state, e.country
)
-- Step 2: Rank the regions and calculate percentage contribution
SELECT 
    employee_city,
    employee_state,
    employee_country,
    region_revenue,
    ROUND((region_revenue / SUM(region_revenue) OVER ()) * 100, 2) AS percent_of_total_revenue
FROM EmployeeRegionRevenue
ORDER BY region_revenue DESC;


--GEOGRAPHIC TRENDS

-- QUESTION 1. Which countries or cities have the highest number of customers?

WITH CityCustomerCount AS (
    -- Step 1: Count customers per city and country
    SELECT 
        country,
        city,
        COUNT(customer_id) AS number_of_customers
    FROM customer
    GROUP BY country, city
)
-- Step 2: Rank the cities globally AND domestically
SELECT 
    country,
    city,
    number_of_customers,
    DENSE_RANK() OVER (ORDER BY number_of_customers DESC) AS global_rank,
    DENSE_RANK() OVER (PARTITION BY country ORDER BY number_of_customers DESC) AS rank_in_country
FROM CityCustomerCount
ORDER BY global_rank, country
LIMIT 10;


-- QUESTION 2.How does revenue vary by region?

WITH RegionRevenue AS (
    -- Step 1: Aggregate total customers and revenue by country
    SELECT 
        c.country,
        COUNT(DISTINCT c.customer_id) AS total_customers,
        SUM(i.total) AS total_revenue
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.country
)
-- Step 2: Calculate averages and percentages using Window Functions
SELECT 
    country,
    total_customers,
    total_revenue,
    ROUND(total_revenue / total_customers, 2) AS revenue_per_customer,
    ROUND((total_revenue / SUM(total_revenue) OVER ()) * 100, 2) AS percent_of_global_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS global_revenue_rank
FROM RegionRevenue
ORDER BY global_revenue_rank;


-- QUESTION 3 Are there any underserved geographic regions (high users, low sales)?


WITH EmployeeRegionRevenue AS (
    -- Step 1: Aggregate revenue based on where the EMPLOYEE is located
    SELECT 
        e.city AS employee_city,
        e.state AS employee_state,
        e.country AS employee_country,
        SUM(i.total) AS region_revenue
    FROM employee e
    JOIN customer c ON e.employee_id = c.support_rep_id
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY e.city, e.state, e.country
)
-- Step 2: Rank the regions and calculate percentage contribution
SELECT 
    employee_city,
    employee_state,
    employee_country,
    region_revenue,
    ROUND((region_revenue / SUM(region_revenue) OVER ()) * 100, 2) AS percent_of_total_revenue
FROM EmployeeRegionRevenue
ORDER BY region_revenue DESC;



WITH CustomerGenres AS (
    -- Step 1: Count the unique genres purchased by each customer
    SELECT 
        i.customer_id,
        COUNT(DISTINCT t.genre_id) AS unique_genres_purchased
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    GROUP BY i.customer_id
)
-- Step 2: Calculate the percentage of multi-genre buyers
SELECT 
    COUNT(customer_id) AS total_customers,
    SUM(CASE WHEN unique_genres_purchased > 1 THEN 1 ELSE 0 END) AS multi_genre_customers,
    ROUND(
        (SUM(CASE WHEN unique_genres_purchased > 1 THEN 1 ELSE 0 END)::numeric / COUNT(customer_id)) * 100, 
    2) AS percentage_multi_genre
FROM CustomerGenres;


WITH CustomerGenres AS (
    -- Step 1: Count the unique genres purchased by each customer
    SELECT 
        i.customer_id,
        COUNT(DISTINCT t.genre_id) AS unique_genres_purchased
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    GROUP BY i.customer_id
)
-- Step 2: Calculate the percentage of multi-genre buyers
SELECT 
    COUNT(customer_id) AS total_customers,
    SUM(CASE WHEN unique_genres_purchased > 1 THEN 1 ELSE 0 END) AS multi_genre_customers,
    ROUND(
        (SUM(CASE WHEN unique_genres_purchased > 1 THEN 1 ELSE 0 END)::numeric / COUNT(customer_id)) * 100, 
    2) AS percentage_multi_genre
FROM CustomerGenres;


-- CUSTOMER RETENTION & PURCHASE PATTERNS

-- QUESTION 1. What is the distribution of purchase frequency per customer?

WITH CustomerPurchaseCount AS (
    -- Step 1: Count total invoices per customer
    SELECT 
        customer_id,
        COUNT(invoice_id) AS total_purchases
    FROM invoice
    GROUP BY customer_id
)
-- Step 2: Group by the purchase frequency to see the distribution
SELECT 
    total_purchases AS purchases_made_in_lifetime,
    COUNT(customer_id) AS number_of_customers
FROM CustomerPurchaseCount
GROUP BY total_purchases
ORDER BY purchases_made_in_lifetime ASC;


-- QUESTION 2. How long is the average time between customer purchases?

WITH PurchaseDates AS (
    -- Step 1: Fetch current invoice date and the previous invoice date
    SELECT 
        customer_id,
        invoice_date,
        LAG(invoice_date) OVER (PARTITION BY customer_id ORDER BY invoice_date) AS previous_purchase_date
    FROM invoice
)
-- Step 2: Calculate the average days between the dates
SELECT 
    ROUND(AVG(DATE_PART('day', invoice_date - previous_purchase_date))::numeric, 2) AS avg_days_between_purchases
FROM PurchaseDates
WHERE previous_purchase_date IS NOT NULL;


-- QUESTION 3 What percentage of customers purchase tracks from more than one genre?

WITH CustomerGenres AS (
    -- Step 1: Count the unique genres purchased by each customer
    SELECT 
        i.customer_id,
        COUNT(DISTINCT t.genre_id) AS unique_genres_purchased
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    GROUP BY i.customer_id
)
-- Step 2: Calculate the percentage of multi-genre buyers
SELECT 
    COUNT(customer_id) AS total_customers,
    SUM(CASE WHEN unique_genres_purchased > 1 THEN 1 ELSE 0 END) AS multi_genre_customers,
    ROUND(
        (SUM(CASE WHEN unique_genres_purchased > 1 THEN 1 ELSE 0 END)::numeric / COUNT(customer_id)) * 100, 
    2) AS percentage_multi_genre
FROM CustomerGenres;


--OPERATIONAL OPTIMIZATION

-- QUESTIOM 1. What are the most common combinations of tracks purchased together?

WITH TrackCombinations AS (
    -- Step 1: Self-join to find tracks bought in the exact same cart
    SELECT 
        il1.track_id AS track_id_1,
        il2.track_id AS track_id_2,
        COUNT(*) AS times_purchased_together
    FROM invoice_line il1
    JOIN invoice_line il2 ON il1.invoice_id = il2.invoice_id
    WHERE il1.track_id < il2.track_id 
    GROUP BY il1.track_id, il2.track_id
)
-- Step 2: Join back to the track table to get the actual song names and Rank them
SELECT 
    t1.name AS track_1_name,
    t2.name AS track_2_name,
    tc.times_purchased_together,
    DENSE_RANK() OVER (ORDER BY tc.times_purchased_together DESC) AS combo_popularity_rank
FROM TrackCombinations tc
JOIN track t1 ON tc.track_id_1 = t1.track_id
JOIN track t2 ON tc.track_id_2 = t2.track_id
ORDER BY combo_popularity_rank
LIMIT 5;


-- QUESTION 2. Are there pricing patterns that lead to higher or lower sales?

WITH InventoryCost AS (
    -- Step 1: Count how many tracks exist at each price point
    SELECT 
        unit_price AS price_point,
        COUNT(track_id) AS total_available_tracks
    FROM track
    GROUP BY unit_price
),
SalesAtCost AS (
    -- Step 2: Sum the actual sales at each price point
    SELECT 
        t.unit_price AS price_point,
        SUM(il.quantity) AS total_tracks_sold,
        SUM(il.unit_price * il.quantity) AS total_revenue
    FROM invoice_line il
    JOIN track t ON il.track_id = t.track_id
    GROUP BY t.unit_price
)
-- Step 3: Compare Inventory vs Sales to find pricing patterns
SELECT 
    i.price_point,
    i.total_available_tracks,
    COALESCE(s.total_tracks_sold, 0) AS total_tracks_sold,
    COALESCE(s.total_revenue, 0) AS total_revenue,
    ROUND((COALESCE(s.total_tracks_sold, 0)::numeric / i.total_available_tracks), 4) AS average_sales_per_track
FROM InventoryCost i
LEFT JOIN SalesAtCost s ON i.price_point = s.price_point
ORDER BY i.price_point;


-- QUESTION 3. Which media types (e.g., MPEG, AAC) are declining or increasing in usage?

WITH MediaTypeSales AS (
    -- Step 1: Aggregate sales by Media Type and Year
    SELECT 
        mt.name AS media_format,
        EXTRACT(YEAR FROM i.invoice_date) AS sales_year,
        SUM(il.quantity) AS tracks_sold
    FROM invoice_line il
    JOIN invoice i ON il.invoice_id = i.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN media_type mt ON t.media_type_id = mt.media_type_id
    GROUP BY mt.name, EXTRACT(YEAR FROM i.invoice_date)
),
TrendAnalysis AS (
    -- Step 2: Use LAG() to fetch the previous year's sales for comparison
    SELECT 
        media_format,
        sales_year,
        tracks_sold,
        LAG(tracks_sold) OVER (PARTITION BY media_format ORDER BY sales_year) AS previous_year_sales
    FROM MediaTypeSales
)
-- Step 3: Calculate the trend
SELECT 
    media_format,
    sales_year,
    tracks_sold,
    previous_year_sales,
    CASE 
        WHEN previous_year_sales IS NULL THEN 'First Year of Sales'
        WHEN tracks_sold > previous_year_sales THEN 'Increasing 📈'
        WHEN tracks_sold < previous_year_sales THEN 'Declining 📉'
        ELSE 'Flat'
    END AS usage_trend
FROM TrendAnalysis
ORDER BY media_format, sales_year;





