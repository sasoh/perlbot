CREATE TABLE imgs (
        img_id INTEGER PRIMARY KEY,
        nick VARCHAR(64),
        filename VARCHAR(255),
        filetype VARCHAR(255),
        source VARCHAR(255),
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        );

CREATE UNIQUE INDEX img_id ON imgs (img_id);
CREATE UNIQUE INDEX timestamp ON imgs (timestamp);

CREATE TABLE tags (
        tag_id INTEGER PRIMARY KEY,
        tag VARCHAR(64),
        text VARCHAR(255)
        );

CREATE UNIQUE INDEX tag_id ON tags (tag_id);

CREATE TABLE urls (
        url_id INTEGER PRIMARY KEY,
        nick VARCHAR(64),
        source VARCHAR(255),
        timest DATETIME DEFAULT CURRENT_TIMESTAMP
        );

CREATE UNIQUE INDEX url_id ON urls (url_id);
CREATE UNIQUE INDEX timest ON urls (timest);
