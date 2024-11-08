-- OBJECTIVE QUESTIONS

-- 1.	List the different dtypes of columns in table “ball_by_ball” (using information schema)

SELECT 
    COLUMN_NAME, DATA_TYPE
FROM
    information_schema.columns
WHERE
    TABLE_NAME = 'ball_by_ball';
    
-- 2.	What is the total number of run scored in 1st season by RCB (bonus : also include the extra runs using the extra runs table)

WITH Totalruns AS (
    SELECT 
        SUM(bs.Runs_Scored) + SUM(er.Extra_Runs) AS Total_Runs,  
        t.Team_Id
    FROM 
        matches m
    INNER JOIN 
        team t ON m.Team_1 = t.Team_Id  
    INNER JOIN 
        ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN 
        batsman_scored bs ON ball.Match_Id = bs.Match_Id 
        AND ball.Over_Id = bs.Over_Id 
        AND ball.Ball_Id = bs.Ball_Id
    LEFT JOIN 
        extra_runs er ON ball.Match_Id = er.Match_Id 
        AND ball.Over_Id = er.Over_Id 
        AND ball.Ball_Id = er.Ball_Id
    WHERE 
        t.Team_Id = 2  -- RCB's team id is 2 
        AND m.Season_Id = 1  -- Filter for 1st season
        AND ball.Team_Batting = t.Team_Id  -- Ensure the correct batting team
    GROUP BY 
        t.Team_Id
)
SELECT Total_Runs as RCB_in_season_1
FROM Totalruns;

-- 3.	How many players were more than age of 25 during season 2 ?

SELECT 
    COUNT(DISTINCT p.Player_Id) AS Number_of_Players_Above_25
FROM
    player p
        INNER JOIN
    player_match pm ON p.Player_Id = pm.Player_Id
        INNER JOIN
    matches m ON pm.Match_Id = m.Match_Id
        INNER JOIN
    season s ON m.Season_Id = s.Season_Id
WHERE
    s.Season_id = 2
        AND TIMESTAMPDIFF(YEAR, p.DOB, m.Match_Date) > 25;

-- 4.	How many matches did RCB win in season 1 ?     

SELECT COUNT(*) AS RCB_Wins_Season_1
FROM matches m
INNER JOIN season s ON s.Season_Id = m.Season_Id 
INNER JOIN team t ON t.Team_Id = m.Match_Winner
WHERE Team_Name = 'Royal Challengers Bangalore' AND s.Season_Id = 1;    


-- 5.	List top 10 players according to their strike rate in last 4 seasons

WITH PlayerStrikeRates AS (
    SELECT p.Player_Name, 
        SUM(bs.Runs_Scored) AS Total_runs,
        COUNT(bs.Ball_Id) AS Balls_Faced,
        ROUND((SUM(bs.Runs_Scored) / COUNT(bs.Ball_Id)) * 100 ,2) AS Strike_rate,
        ROW_NUMBER() OVER (ORDER BY (SUM(bs.Runs_Scored) / COUNT(bs.Ball_Id)) * 100 DESC) AS `Rank`
    FROM player p
    INNER JOIN ball_by_ball ball ON ball.Striker = p.Player_Id
    INNER JOIN matches m ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON bs.Match_Id = ball.Match_Id AND bs.Over_Id = ball.Over_Id AND bs.Ball_Id = ball.Ball_Id
    INNER JOIN season s ON s.Season_Id = m.Season_Id
    WHERE s.Season_Id IN (9, 8, 7, 6) 
    GROUP BY p.Player_Id, p.Player_Name
    HAVING COUNT(bs.Ball_Id) > 0
)
SELECT `Rank`,Player_Name, Total_runs, Balls_Faced, Strike_rate FROM PlayerStrikeRates
WHERE `Rank` <= 10;


-- For identifying batters

WITH PlayerStrikeRates AS (
    SELECT p.Player_Name, 
        SUM(bs.Runs_Scored) AS Total_runs,
        COUNT(bs.Ball_Id) AS Balls_Faced,
        ROUND((SUM(bs.Runs_Scored) / COUNT(bs.Ball_Id)) * 100 ,2) AS Strike_rate,
        ROW_NUMBER() OVER (ORDER BY (SUM(bs.Runs_Scored) / COUNT(bs.Ball_Id)) * 100 DESC) AS `Rank`
    FROM player p
    INNER JOIN ball_by_ball ball ON ball.Striker = p.Player_Id
    INNER JOIN matches m ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON bs.Match_Id = ball.Match_Id AND bs.Over_Id = ball.Over_Id AND bs.Ball_Id = ball.Ball_Id
    INNER JOIN season s ON s.Season_Id = m.Season_Id
    WHERE s.Season_Id IN (9, 8, 7, 6) 
    GROUP BY p.Player_Id, p.Player_Name
    HAVING COUNT(bs.Ball_Id) > 250
)
SELECT `Rank`,Player_Name, Total_runs, Balls_Faced, Strike_rate FROM PlayerStrikeRates
WHERE `Rank` <= 10;

-- 6.	What is the average runs scored by each batsman considering all the seasons?

WITH PlayerAvg AS (
SELECT 
	p.Player_Id ,
    p.Player_Name, 
    SUM(distinct bs.Runs_Scored) AS Total_Runs,
    COUNT(DISTINCT bs.Match_Id) AS Innings_Played,  -- Count distinct matches as innings
    SUM(bs.Runs_Scored) / COUNT(DISTINCT bs.Match_Id) AS Average_Runs  -- Calculate average per innings
FROM 
    player p
INNER JOIN 
    ball_by_ball ball ON ball.Striker = p.Player_Id  
INNER JOIN 
    batsman_scored bs ON bs.Match_Id = ball.Match_Id  AND bs.Over_Id = ball.Over_Id AND bs.Ball_Id = ball.Ball_Id 
GROUP BY 
    p.Player_Id ,p.Player_Name
HAVING 
    COUNT(DISTINCT bs.Match_Id) > 0  
ORDER BY Average_Runs DESC
)
SELECT ROW_NUMBER() OVER() AS `Rank`, Player_Name, Average_Runs as Average from PlayerAvg;


-- 7.	What are the average wickets taken by each bowler considering all the seasons?

WITH AverageWickets as (
SELECT 
	   p.Player_Name, 
       ROUND(COUNT(wt.Player_Out) / COUNT(DISTINCT ball.Match_Id),2) AS Average_Wickets
FROM player p
INNER JOIN ball_by_ball ball ON ball.Bowler = p.Player_Id
INNER JOIN wicket_taken wt ON wt.Match_Id = ball.Match_Id 
                          AND wt.Over_Id = ball.Over_Id 
                          AND wt.Ball_Id = ball.Ball_Id
GROUP BY p.Player_Name
ORDER BY Average_Wickets DESC)
SELECT Row_number() over() as `Rank`, Player_Name, Average_Wickets from AverageWickets;

-- 8.	List all the players who have average runs scored greater than overall average and who have taken wickets greater than overall average

WITH PlayerRuns AS (
    -- Calculate the average runs per match for each player as a batsman
    SELECT p.Player_Id,p.Player_Name,
        ROUND(SUM(bs.Runs_Scored) / COUNT(DISTINCT ball.Match_Id),2) AS Avg_Runs_Per_Match
    FROM player p
    LEFT JOIN ball_by_ball ball ON p.Player_Id = ball.Striker
    LEFT JOIN batsman_scored bs ON bs.Match_Id = ball.Match_Id AND bs.Over_Id = ball.Over_Id AND bs.Ball_Id = ball.Ball_Id
    GROUP BY p.Player_Id, p.Player_Name
),
PlayerWickets AS (
    -- Calculate the total wickets for each player as a bowler
    SELECT p.Player_Id, COUNT(CASE WHEN ball.Bowler = p.Player_Id THEN wt.Player_Out END) AS Total_Wickets
    FROM player p
    LEFT JOIN ball_by_ball ball ON p.Player_Id = ball.Bowler
    LEFT JOIN wicket_taken wt ON wt.Match_Id = ball.Match_Id AND wt.Over_Id = ball.Over_Id AND wt.Ball_Id = ball.Ball_Id
    GROUP BY p.Player_Id
),
OverallAverages AS (
    -- Calculate overall averages for runs and wickets across all players
    SELECT 
        AVG(pr.Avg_Runs_Per_Match) AS Overall_Avg_Runs,
        AVG(pw.Total_Wickets) AS Overall_Avg_Wickets
    FROM PlayerRuns pr
    INNER JOIN PlayerWickets pw ON pr.Player_Id = pw.Player_Id
)
-- Final query to select players with above-average runs and wickets
SELECT RANK() OVER(ORDER BY pr.Avg_Runs_Per_Match DESC, pw.Total_Wickets DESC ) AS `rank`,
	   pr.Player_Name, pr.Avg_Runs_Per_Match, pw.Total_Wickets
FROM PlayerRuns pr
INNER JOIN PlayerWickets pw ON pr.Player_Id = pw.Player_Id
CROSS JOIN OverallAverages oa
WHERE pr.Avg_Runs_Per_Match > oa.Overall_Avg_Runs AND pw.Total_Wickets > oa.Overall_Avg_Wickets
ORDER BY pr.Avg_Runs_Per_Match DESC, pw.Total_Wickets DESC;

-- 9.	Create a table rcb_record table that shows wins and losses of RCB in an individual venue.

WITH rcb_record AS (
SELECT
    v.Venue_Name,
    COUNT(*) AS Total_Matches,
    SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,
    SUM(CASE WHEN m.Match_Winner != t.Team_Id AND (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id) THEN 1 ELSE 0 END) AS Loses
FROM matches m
INNER JOIN team t ON (t.Team_Name = 'Royal Challengers Bangalore')
INNER JOIN venue v ON m.Venue_Id = v.Venue_Id
WHERE (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id)
GROUP BY v.Venue_Name)

SELECT Venue_Name,Total_Matches,Wins,Loses, (Total_Matches - (Wins + Loses)) as NR  FROM rcb_record; 

-- 10.	What is the impact of bowling style on wickets taken.

SELECT bs.Bowling_skill, COUNT(wt.Player_Out) AS Wickets_Taken
FROM player p
INNER JOIN bowling_style bs ON p.Bowling_skill = bs.Bowling_Id
INNER JOIN ball_by_ball ball ON p.Player_Id = ball.Bowler
INNER JOIN wicket_taken wt ON ball.Match_Id = wt.Match_Id AND ball.Over_Id = wt.Over_Id AND ball.Ball_Id = wt.Ball_Id
WHERE wt.Kind_Out <> 3 -- Removing Run Outs
GROUP BY bs.Bowling_skill

ORDER BY Wickets_Taken DESC;

-- 11.	Write the sql query to provide a status of whether the performance of the team better than the previous year performance on the basis of number of runs scored by the team in the season and number of wickets taken 

WITH TeamPerformance AS (
  SELECT t.Team_Name, s.Season_Year, SUM(bs.Runs_Scored) AS TotalRuns, COUNT(wt.Player_Out) AS TotalWickets
  FROM team t
    INNER JOIN player_match pm ON t.Team_Id = pm.Team_Id
    INNER JOIN matches m ON pm.Match_Id = m.Match_Id
    INNER JOIN (SELECT Match_Id, SUM(Runs_Scored) AS Runs_Scored FROM batsman_scored GROUP BY Match_Id) bs ON m.Match_Id = bs.Match_Id
    INNER JOIN (SELECT Match_Id, COUNT(Player_Out) AS Player_Out FROM wicket_taken GROUP BY Match_Id) wt ON m.Match_Id = wt.Match_Id
    INNER JOIN season s ON m.Season_Id = s.Season_Id
  GROUP BY t.Team_Name, s.Season_Year)
SELECT t1.Team_Name, 
  t1.Season_Year AS Previous_Year, 
  t2.Season_Year AS Current_Year, 
  t1.TotalRuns AS Previous_Runs, 
  t2.TotalRuns AS Current_Runs, 
  t1.TotalWickets AS Previous_Wickets, 
  t2.TotalWickets AS Current_Wickets, 
  CASE 
    WHEN t2.TotalRuns > t1.TotalRuns AND t2.TotalWickets > t1.TotalWickets THEN 'Better'
    WHEN t2.TotalRuns = t1.TotalRuns AND t2.TotalWickets = t1.TotalWickets THEN 'Same'
    WHEN t2.TotalRuns > t1.TotalRuns AND t2.TotalWickets = t1.TotalWickets THEN 'Mixed'
    WHEN t2.TotalRuns = t1.TotalRuns AND t2.TotalWickets > t1.TotalWickets THEN 'Mixed'
    ELSE 'Worse'
  END AS Performance_Status
FROM TeamPerformance t1
  INNER JOIN TeamPerformance t2 ON t1.Team_Name = t2.Team_Name AND t1.Season_Year = t2.Season_Year - 1
ORDER BY t1.Team_Name, t1.Season_Year;

-- 12.	Can you derive more KPIs for the team strategy if possible?

-- Top order stability

WITH Top_Order_Stats AS (
    SELECT m.Match_Id, t.Team_Name, 
        SUM(bs.Runs_Scored) AS Top_Order_Runs, 
        TotalRuns.Match_Total_Runs
    FROM matches m
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
            AND ball.Over_Id = bs.Over_Id 
            AND ball.Ball_Id = bs.Ball_Id
    INNER JOIN team t ON t.Team_Id = ball.Team_Batting
    INNER JOIN (SELECT Match_Id, SUM(Runs_Scored) AS Match_Total_Runs 
         FROM batsman_scored 
         GROUP BY Match_Id) AS TotalRuns ON m.Match_Id = TotalRuns.Match_Id
    WHERE 
        ball.Striker_Batting_Position <= 3 AND t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY 
        m.Match_Id, t.Team_Name, TotalRuns.Match_Total_Runs
)
SELECT 
    Team_Name, 
    ROUND(AVG((Top_Order_Runs / Match_Total_Runs) * 100),2) AS Avg_Top_Order_Contribution
FROM Top_Order_Stats
GROUP BY Team_Name;
    
-- Batting performances

WITH Powerplay_Stats AS (
    SELECT 
        m.Match_Id, t.Team_Name, 
        SUM(bs.Runs_Scored) AS Powerplay_Runs,
        COUNT(CASE WHEN wt.Player_Out IS NOT NULL THEN 1 END) AS Wickets_Lost
    FROM matches m
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
        AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id
    INNER JOIN team t ON t.Team_Id = ball.Team_Batting
    LEFT JOIN wicket_taken wt ON ball.Match_Id = wt.Match_Id 
        AND ball.Over_Id = wt.Over_Id AND ball.Ball_Id = wt.Ball_Id
    WHERE ball.Over_Id BETWEEN 1 AND 6 
        AND t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Match_Id, t.Team_Name
),
Death_Overs_Stats AS (
    SELECT 
        m.Match_Id, t.Team_Name, 
        SUM(bs.Runs_Scored) AS Death_Overs_Runs,
        COUNT(ball.Ball_Id) AS Balls_Faced
    FROM matches m
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
        AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id
    INNER JOIN team t ON t.Team_Id = ball.Team_Batting
    WHERE ball.Over_Id BETWEEN 17 AND 20 
        AND t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Match_Id, t.Team_Name
),
Boundary_Stats AS (
    SELECT 
        m.Match_Id, t.Team_Name,
        SUM(CASE WHEN bs.Runs_Scored IN (4, 6) THEN 1 ELSE 0 END) AS Boundaries,
        COUNT(bs.Ball_Id) AS Total_Balls
    FROM matches m
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
        AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id
    INNER JOIN team t ON t.Team_Id = ball.Team_Batting
    WHERE t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Match_Id, t.Team_Name
)
SELECT 
    p.Team_Name, 
    ROUND(AVG(p.Powerplay_Runs), 2) AS Avg_Powerplay_Runs,
    ROUND(AVG(p.Wickets_Lost), 2) AS Avg_Wickets_Lost_Powerplay,
    ROUND(AVG(d.Death_Overs_Runs / d.Balls_Faced * 100), 2) AS Avg_Death_Overs_Strike_Rate,
    ROUND(AVG(b.Boundaries), 2) AS Avg_Boundaries_Per_Match,
    ROUND(AVG(NULLIF(b.Total_Balls, 0) / NULLIF(b.Boundaries, 0)), 2) AS Boundary_Per_Ball
FROM Powerplay_Stats p
JOIN Death_Overs_Stats d ON p.Team_Name = d.Team_Name
JOIN Boundary_Stats b ON p.Team_Name = b.Team_Name
GROUP BY p.Team_Name;

-- different phase economy (bowling performances)

WITH Powerplay_Economy AS (
    SELECT m.Match_Id, 
           SUM(bs.Runs_Scored) AS Total_Runs_Scored,
           COUNT(DISTINCT ball.Over_Id) AS Total_Overs
    FROM matches m
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
        AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id
    WHERE ball.Over_Id BETWEEN 1 AND 6
      AND ball.Team_Bowling = '2'  -- RCB's ID
    GROUP BY m.Match_Id
),
Middle_Overs_Economy AS (
    SELECT m.Match_Id, 
           SUM(bs.Runs_Scored) AS Total_Runs_Scored,
           COUNT(DISTINCT ball.Over_Id) AS Total_Overs
    FROM matches m
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
        AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id
    WHERE ball.Over_Id BETWEEN 7 AND 15
      AND ball.Team_Bowling = '2'  -- RCB's ID
    GROUP BY m.Match_Id
),
Death_Overs_Economy AS (
    SELECT m.Match_Id, 
           SUM(bs.Runs_Scored) AS Total_Runs_Scored,
           COUNT(DISTINCT ball.Over_Id) AS Total_Overs
    FROM matches m
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    INNER JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
        AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id
    WHERE ball.Over_Id BETWEEN 16 AND 20
      AND ball.Team_Bowling = '2'  -- RCB's ID
    GROUP BY m.Match_Id
)
SELECT 
    AVG(Powerplay.Total_Runs_Scored / Powerplay.Total_Overs) AS Avg_Powerplay_Economy,
    AVG(Middle.Total_Runs_Scored / Middle.Total_Overs) AS Avg_Middle_Overs_Economy,
    AVG(Death.Total_Runs_Scored / Death.Total_Overs) AS Avg_Death_Overs_Economy
FROM Powerplay_Economy Powerplay,
     Middle_Overs_Economy Middle,
     Death_Overs_Economy Death;


-- 13.	Using SQL, write a query to find out average wickets taken by each bowler in each venue. Also rank the gender according to the average value.

WITH AvgWicketsPerVenue AS (
    SELECT 
        p.Player_Id,
        p.Player_Name,
        v.Venue_Name,
        COUNT(wt.Player_Out) AS Total_Wickets, 
        COUNT(DISTINCT m.Match_Id) AS Total_Matches,
        (COUNT(wt.Player_Out) / COUNT(DISTINCT m.Match_Id)) AS Avg_Wickets
    FROM player p
    INNER JOIN ball_by_ball ball ON p.Player_Id = ball.Bowler
    INNER JOIN matches m ON ball.Match_Id = m.Match_Id
    INNER JOIN wicket_taken wt ON ball.Match_Id = wt.Match_Id 
                               AND ball.Over_Id = wt.Over_Id 
                               AND ball.Ball_Id = wt.Ball_Id
    INNER JOIN venue v ON m.Venue_Id = v.Venue_Id
    WHERE wt.Kind_Out <> 3
    GROUP BY p.Player_Id, p.Player_Name, v.Venue_Name
)
-- Adding the rank for each player at each venue
SELECT 
    Player_Id,
    Player_Name,
    Venue_Name,
    Total_Wickets,
    Total_Matches,
    Avg_Wickets,
    RANK() OVER (ORDER BY Avg_Wickets DESC) AS Wicket_Rank
FROM AvgWicketsPerVenue
ORDER BY Wicket_Rank;

-- 14.	Which of the given players have consistently performed well in past seasons? (will you use any visualisation to solve the problem)

WITH Player_Season_Performance AS (
    SELECT 
        p.Player_Name,
        s.Season_Year,
        SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) AS Total_Runs,
        COUNT(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN 1 END) AS Total_Wickets,
        COUNT(DISTINCT m.Match_Id) AS Matches_Played
    FROM player p
    LEFT JOIN ball_by_ball ball ON p.Player_Id = ball.Striker OR p.Player_Id = ball.Bowler
    LEFT JOIN batsman_scored bs ON bs.Match_Id = ball.Match_Id 
                                 AND bs.Over_Id = ball.Over_Id 
                                 AND bs.Ball_Id = ball.Ball_Id
    LEFT JOIN wicket_taken wt ON wt.Match_Id = ball.Match_Id 
                               AND wt.Over_Id = ball.Over_Id 
                               AND wt.Ball_Id = ball.Ball_Id
    LEFT JOIN matches m ON m.Match_Id = ball.Match_Id
    LEFT JOIN season s ON s.Season_Id = m.Season_Id
    GROUP BY p.Player_Name, s.Season_Year
),
Player_Stats AS (
    SELECT 
        Player_Name,
        AVG(Total_Runs) AS Avg_Runs_Per_Season,
        AVG(Total_Wickets) AS Avg_Wickets_Per_Season,
        COUNT(Season_Year) AS Seasons_Played
    FROM Player_Season_Performance
    GROUP BY Player_Name
)
SELECT 
    ROW_NUMBER() OVER () AS `Rank`,
    Player_Name,
    ROUND(Avg_Runs_Per_Season, 2) AS Avg_Runs_Per_Season,
    ROUND(Avg_Wickets_Per_Season, 2) AS Avg_Wickets_Per_Season,
    Seasons_Played
FROM Player_Stats
ORDER BY Avg_Runs_Per_Season DESC, Avg_Wickets_Per_Season DESC
LIMIT 10;

-- 15.	Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 

WITH Player_Performance AS (
    SELECT 
        p.Player_Name, v.Venue_Name, 
        SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) / COUNT(DISTINCT CASE WHEN ball.Striker = p.Player_Id THEN m.Match_Id END) 
        AS Avg_Runs_Per_Match, COUNT(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN 1 END) AS Wickets_Taken
    FROM player p
    LEFT JOIN ball_by_ball ball ON p.Player_Id = ball.Striker OR p.Player_Id = ball.Bowler
    LEFT JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id 
                                 AND ball.Over_Id = bs.Over_Id 
                                 AND ball.Ball_Id = bs.Ball_Id
    LEFT JOIN matches m ON m.Match_Id = ball.Match_Id
    LEFT JOIN venue v ON m.Venue_Id = v.Venue_Id
    LEFT JOIN wicket_taken wt ON wt.Match_Id = ball.Match_Id 
                               AND wt.Over_Id = ball.Over_Id 
                               AND wt.Ball_Id = ball.Ball_Id
                               AND ball.Bowler = p.Player_Id
    GROUP BY p.Player_Name, v.Venue_Name
)
SELECT 
    Player_Name, 
    Venue_Name, 
    ROUND(Avg_Runs_Per_Match, 2) AS Avg_Runs_Per_Match, 
    Wickets_Taken 
FROM Player_Performance
GROUP BY Player_Name, Venue_Name
ORDER BY Avg_Runs_Per_Match DESC, Wickets_Taken DESC;


-- SUBJECTIVE QUESTIONS

-- 1.	How does toss decision have affected the result of the match ? (which visualisations could be used to better present your answer) And is the impact limited to only specific venues?

WITH Toss_Win_Stats AS (
    SELECT v.Venue_Name, 
           td.Toss_Name AS Toss_Decision, 
           COUNT(*) AS Total_Matches,
           SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) AS Matches_Won_After_Toss,
           ROUND((SUM(CASE WHEN m.Match_Winner = m.Toss_Winner THEN 1 ELSE 0 END) / COUNT(*)) * 100, 2) AS Win_Percentage
    FROM matches m
    INNER JOIN toss_decision td ON m.Toss_Decide = td.Toss_Id
    INNER JOIN venue v ON m.Venue_Id = v.Venue_Id
    GROUP BY v.Venue_Name, td.Toss_Name
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY Win_Percentage DESC, Total_Matches DESC) AS S_No,
    Venue_Name, 
    Toss_Decision, 
    Total_Matches, 
    Matches_Won_After_Toss, 
    Win_Percentage
FROM Toss_Win_Stats
WHERE Total_Matches >= 10
ORDER BY Win_Percentage DESC, Total_Matches DESC;

-- 2.	Suggest some of the players who would be best fit for the team?

WITH Player_Stats AS (
    SELECT p.Player_Name, t.Team_Name, 
           SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) AS Total_Runs, 
           SUM(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN 1 ELSE 0 END) AS Total_Wickets_Taken,
           COUNT(DISTINCT m.Match_Id) AS Matches_Played
    FROM player p
    JOIN player_match pm ON p.Player_Id = pm.Player_Id
    JOIN team t ON pm.Team_Id = t.Team_Id
    JOIN matches m ON pm.Match_Id = m.Match_Id
    LEFT JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    LEFT JOIN batsman_scored bs ON m.Match_Id = bs.Match_Id AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id
    LEFT JOIN wicket_taken wt ON ball.Match_Id = wt.Match_Id AND ball.Over_Id = wt.Over_Id AND ball.Ball_Id = wt.Ball_Id
    WHERE ball.Striker = p.Player_Id OR ball.Bowler = p.Player_Id
    GROUP BY p.Player_Name, t.Team_Name
    HAVING Total_Runs > 2000 OR Total_Wickets_Taken > 100
)
SELECT Player_Name, Team_Name, Total_Runs, Total_Wickets_Taken, Matches_Played
FROM Player_Stats
ORDER BY Total_Runs DESC, Total_Wickets_Taken DESC
LIMIT 30;

-- 3.	What are some of parameters that should be focused while selecting the players?

WITH PlayerStats AS (
	SELECT 
		p.Player_Name,
		-- Batting Metrics
		SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) AS Total_Runs,
		ROUND(SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) / COUNT(DISTINCT CASE WHEN ball.Striker = p.Player_Id THEN ball.Match_Id END), 2) AS Avg_Runs_Per_Match,
		ROUND((SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) / NULLIF(COUNT(CASE WHEN ball.Striker = p.Player_Id THEN ball.Ball_Id END), 0)) * 100, 2) AS Strike_Rate,
		
		-- Bowling Metrics
		COUNT(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN 1 END) AS Total_Wickets,
		ROUND(SUM(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN bs.Runs_Scored ELSE 0 END) / NULLIF(COUNT(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN ball.Ball_Id END), 0), 2) AS Bowling_Avg,
		ROUND(NULLIF(COUNT(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN ball.Ball_Id END) / NULLIF(COUNT(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN 1 END), 0), 0), 2) AS Bowling_Strike_Rate
	FROM 
		player p
	LEFT JOIN ball_by_ball ball ON p.Player_Id = ball.Striker OR p.Player_Id = ball.Bowler
	LEFT JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id AND ball.Ball_Id = bs.Ball_Id AND ball.Over_Id = bs.Over_Id
	LEFT JOIN wicket_taken wt ON ball.Match_Id = wt.Match_Id AND ball.Ball_Id = wt.Ball_Id AND ball.Over_Id = wt.Over_Id
	GROUP BY 
		p.Player_Name
	ORDER BY 
		Total_Runs DESC
	LIMIT 10
)
SELECT * FROM PlayerStats;

-- 4.	Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)

WITH Player_Performance AS (
    SELECT 
        p.Player_Name,
        SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) AS Total_Runs,
        SUM(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN 1 ELSE 0 END) AS Total_Wickets,
        ROUND(SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Runs_Per_Match,
        ROUND(SUM(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN 1 ELSE 0 END) / COUNT(DISTINCT m.Match_Id), 2) AS Avg_Wickets_Per_Match
    FROM player p
    LEFT JOIN ball_by_ball ball ON p.Player_Id = ball.Striker OR p.Player_Id = ball.Bowler
    LEFT JOIN batsman_scored bs ON bs.Match_Id = ball.Match_Id AND bs.Over_Id = ball.Over_Id AND bs.Ball_Id = ball.Ball_Id
    LEFT JOIN wicket_taken wt ON wt.Match_Id = ball.Match_Id AND wt.Over_Id = ball.Over_Id AND wt.Ball_Id = ball.Ball_Id
    LEFT JOIN matches m ON m.Match_Id = ball.Match_Id
    GROUP BY p.Player_Name
    HAVING Total_Runs >= 500 AND Total_Wickets >= 30
)
SELECT 
       Player_Name, Total_Runs, Total_Wickets, Avg_Runs_Per_Match, Avg_Wickets_Per_Match
FROM Player_Performance
ORDER BY Total_Wickets DESC, Total_Runs DESC;

-- 5.	Are there players whose presence positively influences the morale and performance of the team? (justify your answer using visualisation)

-- Step 1: Calculate the team's win percentage with each player
WITH PlayerWinStats AS (
    SELECT p.Player_Name, pm.Team_Id, COUNT(m.Match_Id) AS Total_Matches, 
           SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) AS Matches_Won
    FROM player p
    INNER JOIN player_match pm ON p.Player_Id = pm.Player_Id
    INNER JOIN matches m ON pm.Match_Id = m.Match_Id
    WHERE m.Outcome_type = 1 -- considering only completed matches
    GROUP BY p.Player_Name, pm.Team_Id
),
-- Step 2: Calculate Win Percentage for each player
PlayerWinPercentage AS (
    SELECT pws.Player_Name, pws.Team_Id, pws.Total_Matches, pws.Matches_Won, 
           ROUND((pws.Matches_Won / NULLIF(pws.Total_Matches, 0)) * 100, 2) AS Win_Percentage
    FROM PlayerWinStats pws
    WHERE pws.Total_Matches > 5 -- consider players with more than 5 matches
)
-- Step 3: Combine Player Performance (runs scored, wickets taken, etc.)
SELECT pwp.Player_Name, t.Team_Name, pwp.Total_Matches, pwp.Matches_Won, 
       pwp.Win_Percentage
FROM PlayerWinPercentage pwp
INNER JOIN team t ON pwp.Team_Id = t.Team_Id
ORDER BY Win_Percentage DESC
LIMIT 15;

-- 8.	Analyze the impact of home ground advantage on team performance and identify strategies to maximize this advantage for RCB.

WITH HomeMatches AS (
    SELECT t.Team_Name, v.Venue_Name, COUNT(*) AS Matches_Played,
           SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins
    FROM matches m
    JOIN team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    WHERE t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2 
    GROUP BY t.Team_Name, v.Venue_Name
),
WinPercentage AS (
    SELECT Team_Name, Venue_Name, Matches_Played, Wins,
           (1.0 * Wins / Matches_Played) * 100 AS Win_Percentage
    FROM HomeMatches
)
SELECT Team_Name, Venue_Name, Matches_Played, Wins, Win_Percentage
FROM WinPercentage
WHERE Win_Percentage > 0
AND Venue_Name = 'M Chinnaswamy Stadium'
ORDER BY Win_Percentage DESC;

-- 9.	Come up with a visual and analytical analysis with the RCB past seasons performance and potential reasons for them not winning a trophy.

-- Season wise performance
WITH RCB_Performance AS (
    SELECT m.Season_Id, COUNT(m.Match_Id) AS Matches_Played,
           SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
           (COUNT(m.Match_Id) - SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END)) AS Matches_Lost,
           (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) / COUNT(m.Match_Id)) * 100 AS Win_Percentage
    FROM matches m
    INNER JOIN team t ON (t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2)
    WHERE t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Season_Id
)
SELECT s.Season_Year, rp.Matches_Played, rp.Matches_Won, rp.Matches_Lost, rp.Win_Percentage
FROM RCB_Performance rp
INNER JOIN season s ON rp.Season_Id = s.Season_Id
ORDER BY s.Season_Year;

-- Venue wise performance
WITH VenuePerformance AS (
    SELECT v.Venue_Name, COUNT(*) AS Matches_Played,
           SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins
    FROM matches m
    JOIN team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    WHERE (t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2)
      AND t.Team_Name = 'Royal Challengers Bangalore'  -- Only consider RCB's matches
    GROUP BY v.Venue_Name
),
WinPercentage AS (
    SELECT Venue_Name, Matches_Played, Wins,
           (1.0 * Wins / Matches_Played) * 100 AS Win_Percentage
    FROM VenuePerformance
)
SELECT Venue_Name, Matches_Played, Wins, Win_Percentage
FROM WinPercentage
ORDER BY Win_Percentage DESC;

-- Home and away performance

WITH VenuePerformance AS (
    SELECT 
        CASE WHEN v.Venue_Name = 'M Chinnaswamy Stadium' THEN 'M Chinnaswamy Stadium'
		ELSE 'Away or Neutral Venue' END AS Venue_Category,
        COUNT(*) AS Matches_Played,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins
    FROM matches m
    JOIN team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    JOIN venue v ON m.Venue_Id = v.Venue_Id
    WHERE (t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2)
      AND t.Team_Name = 'Royal Challengers Bangalore'  -- Only consider RCB's matches
    GROUP BY 
        CASE WHEN v.Venue_Name = 'M Chinnaswamy Stadium' THEN 'M Chinnaswamy Stadium'
		ELSE 'Away or Neutral Venue' END
),
WinPercentage AS (
    SELECT 
        Venue_Category, Matches_Played, Wins,
        (1.0 * Wins / Matches_Played) * 100 AS Win_Percentage
    FROM VenuePerformance
)
SELECT 
    Venue_Category, Matches_Played, Wins,Win_Percentage
FROM WinPercentage
ORDER BY Venue_Category DESC;

-- Chasing vs Defending

WITH MatchRecords AS (
    SELECT 
        t.Team_Name,
        CASE 
            WHEN (m.Team_1 = t.Team_Id AND m.Toss_Winner = m.Team_1 AND m.Toss_Decide = 'bat') OR 
                 (m.Team_2 = t.Team_Id AND m.Toss_Winner = m.Team_2 AND m.Toss_Decide = 'bat') THEN 'Batting First'
            WHEN (m.Team_1 = t.Team_Id AND m.Toss_Winner = m.Team_1 AND m.Toss_Decide = 'field') OR 
                 (m.Team_2 = t.Team_Id AND m.Toss_Winner = m.Team_2 AND m.Toss_Decide = 'field') THEN 'Batting Second'
            ELSE 
                CASE WHEN m.Team_1 = t.Team_Id THEN 'Batting First'WHEN m.Team_2 = t.Team_Id THEN 'Batting Second'
                END
        END AS Game_Strategy,
        COUNT(*) AS Matches_Played,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins
    FROM matches m
    JOIN team t ON t.Team_Id IN (m.Team_1, m.Team_2)
    WHERE t.Team_Name = 'Royal Challengers Bangalore'  -- Filter for RCB matches only
    GROUP BY t.Team_Name, Game_Strategy
),
WinPercentage AS (
    SELECT 
        Team_Name, Game_Strategy,Matches_Played,Wins,
        (1.0 * Wins / Matches_Played) * 100 AS Win_Percentage
    FROM MatchRecords
)
SELECT 
    Team_Name, Game_Strategy, Matches_Played, Wins, Win_Percentage
FROM WinPercentage
ORDER BY Win_Percentage DESC;

-- Performance of Key Players Across Season

WITH PlayerPerformance AS (
    SELECT 
        p.Player_Name,
        m.Season_Id,
        SUM(CASE WHEN ball.Striker = p.Player_Id THEN bs.Runs_Scored ELSE 0 END) AS Total_Runs,
        COUNT(CASE WHEN ball.Bowler = p.Player_Id AND wt.Player_Out IS NOT NULL THEN wt.Player_Out END) AS Total_Wickets
    FROM player p
    INNER JOIN player_match pm ON p.Player_Id = pm.Player_Id
    INNER JOIN team t ON pm.Team_Id = t.Team_Id
    INNER JOIN matches m ON pm.Match_Id = m.Match_Id
    INNER JOIN ball_by_ball ball ON m.Match_Id = ball.Match_Id
    LEFT JOIN batsman_scored bs ON ball.Match_Id = bs.Match_Id AND ball.Over_Id = bs.Over_Id AND ball.Ball_Id = bs.Ball_Id AND ball.Striker = p.Player_Id
    LEFT JOIN wicket_taken wt ON ball.Match_Id = wt.Match_Id AND ball.Over_Id = wt.Over_Id AND ball.Ball_Id = wt.Ball_Id AND ball.Bowler = p.Player_Id
    WHERE t.Team_Name = 'Royal Challengers Bangalore'  -- Filter for RCB team
    GROUP BY p.Player_Name, m.Season_Id
)
SELECT 
    Player_Name, 
    Season_Id,
    Total_Runs, 
    Total_Wickets
FROM PlayerPerformance
ORDER BY Total_Runs DESC, Total_Wickets DESC;

-- 11.	In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

UPDATE `Match`
SET Opponent_Team = 'Delhi_Daredevils'
WHERE Opponent_Team = 'Delhi_Capitals';
