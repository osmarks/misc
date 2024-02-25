CREATE TABLE IF NOT EXISTS input_to_hidden (
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    parameter REAL NOT NULL,
    PRIMARY KEY (x, y)
);
CREATE TABLE IF NOT EXISTS hidden_to_hidden (
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    parameter REAL NOT NULL,
    PRIMARY KEY (x, y)
);
CREATE TABLE IF NOT EXISTS hidden_to_output (
    x INTEGER NOT NULL,
    y INTEGER NOT NULL,
    parameter REAL NOT NULL,
    PRIMARY KEY (x, y)
);
CREATE TABLE IF NOT EXISTS hidden_bias (
    x INTEGER NOT NULL PRIMARY KEY,
    parameter REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS output_bias (
    x INTEGER NOT NULL PRIMARY KEY,
    parameter REAL NOT NULL
);
WITH RECURSIVE
    empty_state (x, activation) AS (VALUES (0, 0.0) UNION ALL SELECT x+1 AS x, activation FROM empty_state WHERE x <= (SELECT MAX(x) FROM hidden_bias)),
    empty_input (x, activation) AS (VALUES (0, 0.0) UNION ALL SELECT x+1 AS x, activation FROM empty_input WHERE x <= (SELECT MAX(x) FROM output_bias)),
    hidden_states (i, x, activation) AS (
        SELECT 0, x, activation FROM empty_state
        UNION ALL SELECT a.i + 1, a.x, TANH(a.activation) from h_raw AS a),
    input (i, x, activation) AS (VALUES (0, 4, 1.0) UNION ALL SELECT 0, * FROM empty_input WHERE x <> 4),
    input_embedding (i, x, activation) AS (SELECT input.i, l.y, SUM(activation * l.parameter) FROM input_to_hidden AS l, input WHERE l.x = input.x GROUP BY l.y),
    h2h_out (i, x, activation) AS (SELECT hidden_states.i, l.y, SUM(activation * l.parameter) FROM hidden_to_hidden AS l, hidden_states WHERE l.x = empty_state.x GROUP BY l.y),
    h_raw (i, x, activation) AS (SELECT a.i, a.x, a.activation + b.parameter + c.activation FROM input_embedding AS a, hidden_bias AS b, h2h_out AS c WHERE a.x = b.x AND b.x = c.x AND a.i = c.i),
    output_pre_bias (i, x, activation) AS (SELECT v.i, l.y, SUM(activation * l.parameter) FROM hidden_to_output AS l, hidden_states AS v WHERE l.x = v.x GROUP BY l.y),
    output_logits (i, x, activation) AS (SELECT a.i, a.x, a.activation + b.parameter FROM output_pre_bias AS a, output_bias AS b WHERE a.x = b.x),
    output_probabilities (i, x, activation) AS (SELECT a.i, a.x, EXP(a.activation) / SUM(EXP(b.activation)) from output_logits AS a, output_logits AS b WHERE a.i = b.i GROUP BY a.x),
    sampling_cprob (i, value) AS (SELECT i, ABS(RANDOM()) / 9223372036854775807.0 FROM input GROUP BY input.i),
    sample (i, value) AS (SELECT a.i, a.x FROM output_probabilities AS a WHERE (SELECT SUM(b.activation) FROM output_probabilities AS b WHERE b.x <= a.x AND a.i = b.i) > (SELECT value FROM sampling_cprob) ORDER BY a.x ASC LIMIT 1)
SELECT * FROM sample;