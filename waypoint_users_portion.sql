/* total checkin times by users */
WITH checkin_time_by_users AS (
    SELECT 
        user_id, 
        COUNT(DISTINCT id) AS checkin_times 
    FROM lantern_checkins
    GROUP BY user_id
),

/* reported grade by users */
user_reported_grade AS (
    SELECT
        users.id AS user_id,
        lantern_grades.short_title AS raw_grade_title,
        (CASE 
            WHEN regexp_like(raw_grade_title, '^[0-9]+$') THEN raw_grade_title::INT
            WHEN regexp_like(raw_grade_title, '^[0-9]+[A-Za-z]$') THEN regexp_replace(raw_grade_title,'[A-Za-z]*', '')::INT
            WHEN raw_grade_title = 'A1' THEN 9
            WHEN raw_grade_title = 'G' THEN 10
            WHEN raw_grade_title = 'A2' THEN 11
            WHEN raw_grade_title = 'IM1' THEN 9
            WHEN raw_grade_title = 'IM2' THEN 10
            WHEN raw_grade_title = 'IM3' THEN 11
        END) AS reported_grade,
        MAX(lantern_gradesnapshots.knowledge_graph_snapshot_id) AS last_snapshot_id
    FROM users
    JOIN students ON students.id = users.id
    LEFT JOIN schools ON users.school_id = schools.id
    LEFT JOIN lantern_grades ON lantern_grades.id = students.lantern_grade_id
    LEFT JOIN lantern_gradesnapshots ON lantern_gradesnapshots.user_id = users.id
    LEFT JOIN checkin_time_by_users ON checkin_time_by_users.user_id = users.id
    WHERE true
        AND students.is_active = true 
        [[AND checkin_times >= {{Minimum_checkins}}]] 
        [[AND {{school}}]]
    GROUP BY users.id, raw_grade_title
),

/* calculated performance grade by users */ 
overall_grade_proficiency AS (
    SELECT
        user_reported_grade.user_id,
        user_reported_grade.reported_grade,
        FLOOR(2 + SUM(lantern_gradesnapshots.true_proficiency), 1) AS overall_grade,
        overall_grade - reported_grade AS grade_diff,
        (CASE 
            WHEN reported_grade IS NOT NULL AND overall_grade IS NOT NULL THEN 'At least 1 checkin'
            ELSE 'No checkin'
        END) AS has_overall
    FROM user_reported_grade
    LEFT JOIN lantern_gradesnapshots ON lantern_gradesnapshots.knowledge_graph_snapshot_id = user_reported_grade.last_snapshot_id
    WHERE true 
        [[AND reported_grade = {{Grade}}]]
    GROUP BY user_reported_grade.user_id, user_reported_grade.reported_grade
)

SELECT 
    COUNT(DISTINCT user_id) AS number_of_users, 
    has_overall
FROM overall_grade_proficiency 
GROUP BY has_overall 
ORDER BY has_overall
