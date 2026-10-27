CREATE TABLE networks (
    id TEXT PRIMARY KEY NOT NULL CHECK (length(id) > 0),
    ipv4 TEXT NOT NULL CHECK (length(ipv4) BETWEEN 9 AND 18),
    gateway_cidr TEXT NOT NULL CHECK (length(gateway_cidr) BETWEEN 10 AND 18 AND substr(gateway_cidr, -3) = "/32"),
    desired_revision INTEGER NOT NULL DEFAULT 0 CHECK (desired_revision >= 0),
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
) STRICT;

CREATE TRIGGER networks_identity_immutable
BEFORE UPDATE OF id, ipv4_cidr, gateway_cidr
ON networks
WHEN NEW.id != OLD.id
  OR NEW.ipv4_cidr != OLD.ipv4_cidr
  OR NEW.gateway_cidr != OLD.gateway_cidr
BEGIN
    SELECT RAISE(
        ABORT,
        'network identity and addressing are immutable'
    );
END;

CREATE TABLE devices (
    id TEXT PRIMARY KEY NOT NULL CHECK (length(id) > 0),
    network_id TEXT NOT NULL REFERENCES networks(id) ON DELETE RESTRICT,
    name TEXT NOT NULL CHECK (length(name) BETWEEN 10 AND 250),
    wireguard_public_key BLOB NOT NULL CHECK (length(wireguard_public_key) = 32),
    overlay_cidr TEXT NOT NULL CHECK (length(overlay_cidr) BETWEEN 10 AND 18 AND substr(overlay_cidr, -3) = '/32'),
    membership_state TEXT NOT NULL DEFAULT 'pending' CHECK (membership_state IN ('pending', 'active', 'revoked')),
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    last_contact_at INTEGER,
    revoked_at INTEGER,

    CHECK (
        ( membership_state = 'revoked' AND revoked_at IS NOT NULL )
        OR
        ( membership_state != 'revoked' AND revoked_at IS NULL )
    ),

    UNIQUE (network_id, name),
    UNIQUE (network_id, overlay_cidr),
    UNIQUE (network_id, wireguard_public_key)
) STRICT;

CREATE TRIGGER devices_identity_immutable
BEFORE UPDATE OF id, network_id, overlay_cidr
ON devices
WHEN NEW.id != OLD.id
  OR NEW.network_id != OLD.network_id
  OR NEW.overlay_cidr != OLD.overlay_cidr
BEGIN
    SELECT RAISE(
        ABORT,
        'device identity and address are immutable'
    );
END;

CREATE TRIGGER devices_reject_gateway_address
BEFORE INSERT ON devices
WHEN EXISTS (
    SELECT 1
    FROM networks
    WHERE id = NEW.network_id
      AND gateway_cidr = NEW.overlay_cidr
)
BEGIN
    SELECT RAISE(
        ABORT,
        'gateway address cannot be assigned to a device'
    );
END;
