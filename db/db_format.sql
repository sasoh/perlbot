CREATE TABLE urls (
        url_id INTEGER PRIMARY KEY,
        nick VARCHAR(64),
        filename VARCHAR(255),
        filetype VARCHAR(255),
        source VARCHAR(255),
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );

CREATE UNIQUE INDEX url_id ON urls (url_id);
CREATE UNIQUE INDEX timestamp ON urls (timestamp);
