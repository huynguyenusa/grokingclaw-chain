/// GrokingClaw Agent Identity — On-chain identity for AI agents
/// 
/// This module implements the core identity primitive for AI agents on
/// GrokingClaw Chain. Each agent gets a unique, verifiable identity that:
/// - Is owned by the agent's operator (human or another agent)
/// - Contains the agent's public key for cryptographic verification
/// - Supports delegation chains (agent A delegates to agent B)
/// - Tracks creation time and metadata
/// - Can be revoked by the owner
///
/// This is the Move equivalent of GrokingClawID's Rust identity system,
/// but on-chain — making it verifiable by any chain participant.
module agent_identity::agent_identity {
    use std::string::String;
    use iota::object::{Self, UID};
    use iota::transfer;
    use iota::tx_context::{Self, TxContext};
    use iota::event;
    use iota::clock::{Self, Clock};
    use iota::table::{Self, Table};
    use iota::vec_set::{Self, VecSet};

    // ============ Error Codes ============
    
    /// Identity has been revoked
    const E_IDENTITY_REVOKED: u64 = 1;
    /// Delegation not authorized
    const E_NOT_AUTHORIZED: u64 = 2;
    /// Identity already exists for this agent
    const E_ALREADY_EXISTS: u64 = 3;
    /// Delegation chain too deep
    const E_DELEGATION_TOO_DEEP: u64 = 4;
    /// Maximum delegation depth
    const MAX_DELEGATION_DEPTH: u64 = 5;

    // ============ Core Types ============

    /// The core identity object for an AI agent.
    /// Owned by the agent's operator. Transferable.
    public struct AgentIdentity has key, store {
        id: UID,
        /// Human-readable name (e.g., "naja-v3", "ridges-agent")
        name: String,
        /// Agent's Ed25519 public key (32 bytes, hex-encoded)
        public_key: vector<u8>,
        /// Key algorithm: 0 = Ed25519, 1 = ML-DSA-65 (post-quantum)
        key_algorithm: u8,
        /// SPIFFE ID (e.g., "spiffe://grokingclaw.com/agent/naja-v3")
        spiffe_id: String,
        /// Agent runtime/framework (e.g., "claude-code", "openai", "custom")
        runtime: String,
        /// Timestamp of identity creation (ms since epoch)
        created_at_ms: u64,
        /// Whether this identity has been revoked
        revoked: bool,
        /// Address that created this identity (for audit)
        creator: address,
    }

    /// Delegation: Agent A authorizes Agent B to act on its behalf.
    /// Stored as a shared object so both parties can reference it.
    public struct Delegation has key, store {
        id: UID,
        /// The delegator (who grants authority)
        delegator: address,
        /// The delegate (who receives authority)  
        delegate: address,
        /// Scope of delegation (e.g., "full", "read-only", "sign-transactions")
        scope: String,
        /// Optional expiry timestamp (0 = no expiry)
        expires_at_ms: u64,
        /// Depth in delegation chain (0 = direct, max 5)
        depth: u64,
        /// Whether this delegation is active
        active: bool,
        /// When the delegation was created
        created_at_ms: u64,
    }

    /// Global registry of all agent identities (shared object).
    /// Allows lookup by address.
    public struct IdentityRegistry has key {
        id: UID,
        /// Total identities registered
        total_identities: u64,
        /// Total active delegations
        total_delegations: u64,
        /// Revoked identity count
        total_revoked: u64,
    }

    // ============ Events ============

    /// Emitted when a new agent identity is created
    public struct IdentityCreated has copy, drop {
        identity_id: address,
        name: String,
        public_key: vector<u8>,
        creator: address,
        timestamp_ms: u64,
    }

    /// Emitted when an identity is revoked
    public struct IdentityRevoked has copy, drop {
        identity_id: address,
        revoked_by: address,
        timestamp_ms: u64,
    }

    /// Emitted when a delegation is created
    public struct DelegationCreated has copy, drop {
        delegation_id: address,
        delegator: address,
        delegate: address,
        scope: String,
        timestamp_ms: u64,
    }

    /// Emitted when a delegation is revoked
    public struct DelegationRevoked has copy, drop {
        delegation_id: address,
        revoked_by: address,
        timestamp_ms: u64,
    }

    // ============ Init ============

    /// Initialize the global registry (called once at package publish)
    fun init(ctx: &mut TxContext) {
        let registry = IdentityRegistry {
            id: object::new(ctx),
            total_identities: 0,
            total_delegations: 0,
            total_revoked: 0,
        };
        transfer::share_object(registry);
    }

    // ============ Public Functions ============

    /// Create a new agent identity.
    /// The identity is transferred to the caller (owner).
    public entry fun create_identity(
        registry: &mut IdentityRegistry,
        name: String,
        public_key: vector<u8>,
        key_algorithm: u8,
        spiffe_id: String,
        runtime: String,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let now = clock::timestamp_ms(clock);

        let identity = AgentIdentity {
            id: object::new(ctx),
            name,
            public_key,
            key_algorithm,
            spiffe_id,
            runtime,
            created_at_ms: now,
            revoked: false,
            creator: sender,
        };

        let identity_addr = object::uid_to_address(&identity.id);

        // Emit creation event
        event::emit(IdentityCreated {
            identity_id: identity_addr,
            name: identity.name,
            public_key: identity.public_key,
            creator: sender,
            timestamp_ms: now,
        });

        registry.total_identities = registry.total_identities + 1;

        // Transfer to the creator
        transfer::transfer(identity, sender);
    }

    /// Revoke an agent identity. Only the owner can revoke.
    public entry fun revoke_identity(
        registry: &mut IdentityRegistry,
        identity: &mut AgentIdentity,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(!identity.revoked, E_IDENTITY_REVOKED);
        
        identity.revoked = true;
        let now = clock::timestamp_ms(clock);

        event::emit(IdentityRevoked {
            identity_id: object::uid_to_address(&identity.id),
            revoked_by: tx_context::sender(ctx),
            timestamp_ms: now,
        });

        registry.total_revoked = registry.total_revoked + 1;
    }

    /// Create a delegation from the caller to another agent.
    public entry fun delegate_authority(
        registry: &mut IdentityRegistry,
        identity: &AgentIdentity,
        delegate: address,
        scope: String,
        expires_at_ms: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // Identity must not be revoked
        assert!(!identity.revoked, E_IDENTITY_REVOKED);

        let sender = tx_context::sender(ctx);
        let now = clock::timestamp_ms(clock);

        let delegation = Delegation {
            id: object::new(ctx),
            delegator: sender,
            delegate,
            scope,
            expires_at_ms,
            depth: 0,
            active: true,
            created_at_ms: now,
        };

        event::emit(DelegationCreated {
            delegation_id: object::uid_to_address(&delegation.id),
            delegator: sender,
            delegate,
            scope: delegation.scope,
            timestamp_ms: now,
        });

        registry.total_delegations = registry.total_delegations + 1;

        // Share so both parties can access
        transfer::share_object(delegation);
    }

    /// Revoke a delegation. Only the delegator can revoke.
    public entry fun revoke_delegation(
        registry: &mut IdentityRegistry,
        delegation: &mut Delegation,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(delegation.active, E_IDENTITY_REVOKED);
        assert!(delegation.delegator == tx_context::sender(ctx), E_NOT_AUTHORIZED);

        delegation.active = false;

        event::emit(DelegationRevoked {
            delegation_id: object::uid_to_address(&delegation.id),
            revoked_by: tx_context::sender(ctx),
            timestamp_ms: clock::timestamp_ms(clock),
        });
    }

    // ============ View Functions ============

    /// Check if an identity is valid (exists and not revoked)
    public fun is_valid(identity: &AgentIdentity): bool {
        !identity.revoked
    }

    /// Get identity name
    public fun name(identity: &AgentIdentity): &String {
        &identity.name
    }

    /// Get identity public key
    public fun public_key(identity: &AgentIdentity): &vector<u8> {
        &identity.public_key
    }

    /// Get identity SPIFFE ID
    public fun spiffe_id(identity: &AgentIdentity): &String {
        &identity.spiffe_id
    }

    /// Get identity runtime
    public fun runtime(identity: &AgentIdentity): &String {
        &identity.runtime
    }

    /// Get creation timestamp
    public fun created_at(identity: &AgentIdentity): u64 {
        identity.created_at_ms
    }

    /// Get identity creator
    public fun creator(identity: &AgentIdentity): address {
        identity.creator
    }

    /// Check if delegation is active and not expired
    public fun is_delegation_valid(delegation: &Delegation, clock: &Clock): bool {
        if (!delegation.active) return false;
        if (delegation.expires_at_ms > 0 && clock::timestamp_ms(clock) > delegation.expires_at_ms) {
            return false
        };
        true
    }

    /// Get total registered identities
    public fun total_identities(registry: &IdentityRegistry): u64 {
        registry.total_identities
    }
}
