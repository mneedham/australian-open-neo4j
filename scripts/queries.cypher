// Show the path to the final of the winner as a graph
MATCH path = (p:Player)-[:WINNER]->(match:Match {round: "F"})<-[:NEXT_MATCH*]-(m)<-[:WINNER]-(p)
WHERE not((m)<-[:NEXT_MATCH]-()) AND (match)-[:IN_TOURNAMENT]-(:Tournament {year: 2019})
RETURN path, [node in nodes(path) WHERE node:Match | [path = (p1)-[:WINNER]->(node)<-[:LOSER]-(p2) | path]];

// Matches where the winner lost a set
WITH apoc.map.fromLists( $rounds, range(0, size($rounds)-1)) AS rounds
MATCH (winner:Player)-[:WINNER]->(:Match {round: "F"})-[:IN_TOURNAMENT]->(t)
MATCH (winner)-[:WINNER]->(match)-[:IN_TOURNAMENT]->(t)
WITH winner, match, t
ORDER BY t.year, rounds[match.round]
return winner.name, t.year,
       collect([(match)<-[:IN_MATCH]-(set:Set)
                 WHERE set.matchWinnerScore < set.matchLoserScore | match
               ][0]) AS setDropped

// Matches where the winner lost the first set
WITH apoc.map.fromLists( $rounds, range(0, size($rounds)-1)) AS rounds
MATCH (winner:Player)-[:WINNER]->(:Match {round: "F"})-[:IN_TOURNAMENT]->(t)
MATCH (winner)-[:WINNER]->(match)-[:IN_TOURNAMENT]->(t)
WITH winner, match, t
ORDER BY t.year, rounds[match.round]
return winner.name, t.year,
       collect([(match)<-[:IN_MATCH]-(set:Set {number: 1})
                 WHERE set.matchWinnerScore < set.matchLoserScore | match
               ][0]) AS firstSetDropped

// Winner went the whole tournament without losing a set
WITH apoc.map.fromLists( $rounds, range(0, size($rounds)-1)) AS rounds
MATCH (winner:Player)-[:WINNER]->(:Match {round: "F"})-[:IN_TOURNAMENT]->(t)
MATCH (winner)-[:WINNER]->(match)-[:IN_TOURNAMENT]->(t)
WITH winner, match, t
ORDER BY t.year, rounds[match.round]
WITH winner, t,
     collect([(match)<-[:IN_MATCH]-(set:Set)
              WHERE set.matchWinnerScore < set.matchLoserScore | match
             ][0]) AS setDropped
WHERE size(setDropped) = 0
RETURN winner.name, t.year;

// The draw from the last 8 to the final
MATCH path = (p:Player)-[:WINNER]->(match:Match {round: "F"})<-[:NEXT_MATCH*..2]-(m)
WHERE AND (match)-[:IN_TOURNAMENT]-(:Tournament {year: 2019})
RETURN path, [node in nodes(path) WHERE node:Match | [(p1)-[:WINNER]->(node)<-[:LOSER]-(p2) | [p1, p2]]];

// Find all the finals
MATCH path = (:Tournament)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<--(:Player)
RETURN *;

// Finals lost in a row
MATCH path = (t:Tournament)-[:NEXT_TOURNAMENT*]->(t2:Tournament),
             (t)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:LOSER]-(winner)
WITH nodes(path) AS tournaments, winner
WITH tournaments, tournaments[-1] AS last, tournaments[0] AS first, winner
WITH tournaments, winner, 
     [(last)-[:NEXT_TOURNAMENT]->(next) | next][0] AS next,
     [(previous)-[:NEXT_TOURNAMENT]->(first) | previous][0] AS previous
WHERE all(t in tournaments[1..] 
          WHERE (t)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:LOSER]-(winner)
          AND not((next)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:LOSER]-(winner))
          AND not((previous)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:LOSER]-(winner))
)
RETURN winner.name, [t IN tournaments | t.year], next.year, previous.year;

// Finals won in a row
MATCH path = (t:Tournament)-[:NEXT_TOURNAMENT*]->(t2:Tournament),
             (t)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner)
WITH nodes(path) AS tournaments, winner
WITH tournaments, tournaments[-1] AS last, tournaments[0] AS first, winner
WITH tournaments, winner, 
     [(last)-[:NEXT_TOURNAMENT]->(next) | next][0] AS next,
     [(previous)-[:NEXT_TOURNAMENT]->(first) | previous][0] AS previous
WHERE all(t in tournaments[1..] 
          WHERE (t)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner)
          AND not((next)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner))
          AND not((previous)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner))
)
RETURN winner.name, [t IN tournaments | t.year], next.year, previous.year;

WITH ["mens", "womens"] AS shards
UNWIND fabric.graphIds() AS id
CALL {
  MATCH path = (t:Tournament)-[:NEXT_TOURNAMENT*]->(t2:Tournament),
              (t)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner)
  WITH nodes(path) AS tournaments, winner
  WITH tournaments, tournaments[-1] AS last, tournaments[0] AS first, winner
  WITH tournaments, winner, 
      [(last)-[:NEXT_TOURNAMENT]->(next) | next][0] AS next,
      [(previous)-[:NEXT_TOURNAMENT]->(first) | previous][0] AS previous
  WHERE all(t in tournaments[1..] 
            WHERE (t)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner)
            AND not((next)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner))
            AND not((previous)<-[:IN_TOURNAMENT]-(:Match {round: "F"})<-[:WINNER]-(winner))
  )
  RETURN winner, tournaments
}
RETURN shards[id], winner, tournaments;