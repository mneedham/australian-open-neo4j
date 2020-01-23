:use mens;

call apoc.schema.assert({}, {Player: ["id"], Match: ["id"], Set: ["id"]});

CREATE CONSTRAINT ON (t:Tournament)
ASSERT (t.name, t.year) IS NODE KEY;

// Create initial model
CALL apoc.periodic.iterate(
  "UNWIND range(2000, 2019) AS year RETURN year",
  "WITH 'https://github.com/JeffSackmann/tennis_atp/raw/master/atp_matches_' AS base, year
   LOAD CSV WITH HEADERS FROM base + year + '.csv' AS row
   WITH row, split(row.score, ' ') AS rawSets WHERE row.tourney_name = 'Australian Open'
   WITH row, row.tourney_date + '_' + row.match_num AS matchId

   MERGE (t:Tournament {name: row.tourney_name, year: date(row.tourney_date).year})

   MERGE (m:Match {id: matchId})
   SET m.round = row.round, m.score = row.score

   MERGE (p1:Player {id: row.winner_id})
   SET p1.name = row.winner_name

   MERGE (p2:Player {id: row.loser_id})
   SET p2.name = row.loser_name

   MERGE (p1)-[:WINNER]->(m)
   MERGE (p2)-[:LOSER]->(m)
   MERGE (m)-[:IN_TOURNAMENT]->(t)
", {});

:params rounds: ["R128", "R64", "R32", "R16", "QF", "SF", "F"];

WITH apoc.map.fromLists( $rounds, range(0, size($rounds)-1)) AS rounds
MATCH (t:Tournament)<-[:IN_TOURNAMENT]-(m:Match)<--(player)
WITH player, m, t
ORDER BY player, rounds[m.round]
WITH player, t, collect(m) AS matches
WHERE size(matches) > 1
CALL apoc.nodes.link(matches, "NEXT_MATCH")
RETURN count(*);

MATCH (t:Tournament)
WITH t
ORDER BY t.year
WITH collect(t) AS tournaments
CALL apoc.nodes.link(tournaments, "NEXT_TOURNAMENT")
RETURN count(*);

// Add sets
CALL apoc.periodic.iterate(
  "UNWIND range(2000, 2019) AS year RETURN year",
  "WITH 'https://github.com/JeffSackmann/tennis_atp/raw/master/atp_matches_' AS base, year
   LOAD CSV WITH HEADERS FROM base + year + '.csv' AS row
   WITH row, split(row.score, ' ') AS rawSets WHERE row.tourney_name = 'Australian Open'
   WITH row, rawSets, [set in rawSets | apoc.text.regexGroups(set, \"(\\\\d{1,2})-(\\\\d{1,2})\")[0][1..]] AS sets,
        row.tourney_date + '_' + row.match_num AS matchId

   MATCH (m:Match {id: matchId})
   MATCH (p1:Player {id: row.winner_id})
   MATCH (p2:Player {id: row.loser_id})

   WITH m, sets, rawSets, matchId, p1, p2
   UNWIND range(0, size(sets)-1) AS setNumber
   MERGE (s:Set {id: matchId + '_' + setNumber})
   SET s.matchWinnerScore = toInteger(sets[setNumber][0]),
       s.matchLoserScore = toInteger(sets[setNumber][1]),
       s.score = rawSets[setNumber],
       s.number = setNumber +1
   MERGE (s)-[:IN_MATCH]->(m)
   FOREACH(ignoreMe IN CASE WHEN s.matchWinnerScore >= s.matchLoserScore THEN [1] ELSE [] END |
     MERGE (p1)-[:WINNER]->(s)
     MERGE (p2)-[:LOSER]->(s))
   FOREACH(ignoreMe IN CASE WHEN s.matchWinnerScore < s.matchLoserScore THEN [1] ELSE [] END |
     MERGE (p1)-[:LOSER]->(s)
     MERGE (p2)-[:WINNER]->(s))
", {});
