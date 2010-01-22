CREATE TABLE urls IF NOT EXIST (
        url_id INTEGER PRIMARY KEY,
        nick VARCHAR(64),
        filetype VARCHAR(255),
        timestamp DATE
        );

CREATE UNIQUE INDEX IF NOT EXIST url_id ON urls;
