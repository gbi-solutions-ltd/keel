-- The CSRF token is now derived from the session token (so the server can give it again, to an
-- app on another origin). Sessions made before carry a random one: sign them out once.
DELETE FROM sessions;
