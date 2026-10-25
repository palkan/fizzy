# = Action Pack WebAuthn Authenticator Data
#
# Decodes and represents the authenticator data structure from WebAuthn
# responses. This binary format contains information about the authenticator
# and, during registration, the newly created credential.
#
# == Structure
#
# The authenticator data consists of:
#
# * RP ID Hash (32 bytes) - SHA-256 hash of the relying party ID
# * Flags (1 byte) - Bit flags for user presence, verification, etc.
# * Sign Count (4 bytes) - Signature counter for replay detection
# * Attested Credential Data (variable) - Present only during registration
#
# == Usage
#
#   data = ActionPack::WebAuthn::Authenticator::Data.decode(bytes)
#
#   data.user_present?   # => true
#   data.user_verified?  # => true
#   data.sign_count      # => 42
#   data.credential_id   # => "abc123..." (registration only)
#   data.public_key      # => OpenSSL::PKey::EC (registration only)
#
# == Flags
#
# [+user_present?+]
#   Returns true if the user performed a test of user presence (e.g., touched
#   the authenticator).
#
# [+user_verified?+]
#   Returns true if the user was verified through biometrics, PIN, or other
#   method. This is stronger than mere presence.
#
# [+backup_eligible?+]
#   Returns true if the credential can be backed up (e.g., synced passkeys
#   from Apple, Google, or Microsoft). Indicates multi-device credential support.
#
# [+backed_up?+]
#   Returns true if the credential is currently backed up to cloud storage.
#   Useful for risk assessment—backed-up credentials may be accessible from
#   multiple devices.
#
class ActionPack::WebAuthn::Authenticator::Data
  # @rbs @public_key: OpenSSL::PKey::PKey?

  # Segment lengths
  RELYING_PARTY_ID_HASH_LENGTH = 32
  FLAGS_LENGTH = 1
  SIGN_COUNT_LENGTH = 4
  AAGUID_LENGTH = 16
  CREDENTIAL_ID_LENGTH_BYTES = 2

  # Flags
  USER_PRESENT_FLAG = 0x01
  USER_VERIFIED_FLAG = 0x04
  BACKUP_ELIGIBLE_FLAG = 0x08
  BACKUP_STATE_FLAG = 0x10
  ATTESTED_CREDENTIAL_DATA_FLAG = 0x40

  attr_reader :bytes #: Array[Integer]
  attr_reader :relying_party_id_hash #: String
  attr_reader :flags #: Integer
  attr_reader :sign_count #: Integer
  attr_reader :aaguid #: String?
  attr_reader :credential_id #: String?
  attr_reader :public_key_bytes #: String?

  # Wraps raw authenticator data into a Data instance. Accepts an existing
  # Data object (returned as-is), a Base64URL-encoded string, or raw binary.
  #: (ActionPack::WebAuthn::Authenticator::Data | String) -> ActionPack::WebAuthn::Authenticator::Data
  def self.wrap(data)
    if data.is_a?(ActionPack::WebAuthn::Authenticator::Data)
      data
    else
      data = Base64.urlsafe_decode64(data) unless data.encoding == Encoding::BINARY
      decode(data)
    end
  rescue ArgumentError
    raise ActionPack::WebAuthn::InvalidResponseError, "Invalid base64 encoding in authenticator data"
  end

  # Decodes raw authenticator data bytes into a Data instance, parsing the
  # RP ID hash, flags, sign count, and (if present) attested credential data.
  #: (String | Array[Integer]) -> ActionPack::WebAuthn::Authenticator::Data
  def self.decode(bytes)
    bytes = bytes.bytes if bytes.is_a?(String)

    minimum_length = RELYING_PARTY_ID_HASH_LENGTH + FLAGS_LENGTH + SIGN_COUNT_LENGTH
    if bytes.length < minimum_length
      raise ActionPack::WebAuthn::InvalidResponseError, "Authenticator data is too short"
    end

    position = 0

    relying_party_id_hash = pack_bytes(bytes, position, RELYING_PARTY_ID_HASH_LENGTH)
    position += RELYING_PARTY_ID_HASH_LENGTH

    flags = bytes[position]
    position += FLAGS_LENGTH

    sign_count = pack_bytes(bytes, position, SIGN_COUNT_LENGTH).unpack1("N") #: Integer
    position += SIGN_COUNT_LENGTH

    aaguid = nil
    credential_id = nil
    public_key_bytes = nil

    if flags & ATTESTED_CREDENTIAL_DATA_FLAG != 0
      if bytes.length < position + AAGUID_LENGTH + CREDENTIAL_ID_LENGTH_BYTES
        raise ActionPack::WebAuthn::InvalidResponseError, "Authenticator data is too short for attested credential data"
      end

      aaguid_bytes = pack_bytes(bytes, position, AAGUID_LENGTH)
      aaguid = aaguid_bytes.unpack("H8H4H4H4H12").join("-")
      position += AAGUID_LENGTH

      credential_id_length = pack_bytes(bytes, position, CREDENTIAL_ID_LENGTH_BYTES).unpack1("n") #: Integer
      position += CREDENTIAL_ID_LENGTH_BYTES

      if bytes.length < position + credential_id_length + 1
        raise ActionPack::WebAuthn::InvalidResponseError, "Authenticator data is too short for credential ID and public key"
      end

      credential_id = Base64.urlsafe_encode64(pack_bytes(bytes, position, credential_id_length), padding: false)
      position += credential_id_length

      public_key_bytes = pack_bytes(bytes, position, bytes.length - position)
    end

    new(
      bytes: bytes,
      relying_party_id_hash: relying_party_id_hash,
      flags: flags,
      sign_count: sign_count,
      aaguid: aaguid,
      credential_id: credential_id,
      public_key_bytes: public_key_bytes
    )
  end

  # Packs +length+ bytes starting at +position+ into a binary string. Callers check
  # the data is long enough first, so the slice is never out of range.
  #: (Array[Integer], Integer, Integer) -> String
  private_class_method def self.pack_bytes(bytes, position, length)
    slice = bytes[position, length] #: Array[Integer]
    slice.pack("C*")
  end

  #: (bytes: Array[Integer], relying_party_id_hash: String, flags: Integer, sign_count: Integer, ?aaguid: String?, credential_id: String?, public_key_bytes: String?) -> void
  def initialize(bytes:, relying_party_id_hash:, flags:, sign_count:, aaguid: nil, credential_id:, public_key_bytes:)
    @bytes = bytes
    @relying_party_id_hash = relying_party_id_hash
    @flags = flags
    @sign_count = sign_count
    @aaguid = aaguid
    @credential_id = credential_id
    @public_key_bytes = public_key_bytes
  end

  # Returns true if the user performed a test of presence (e.g., touched the
  # authenticator).
  #: () -> bool
  def user_present?
    flags & USER_PRESENT_FLAG != 0
  end

  # Returns true if the user was verified via biometrics, PIN, or similar.
  #: () -> bool
  def user_verified?
    flags & USER_VERIFIED_FLAG != 0
  end

  # Returns true if the credential is eligible for backup (e.g., synced passkey).
  # This indicates the authenticator supports multi-device credentials.
  #: () -> bool
  def backup_eligible?
    flags & BACKUP_ELIGIBLE_FLAG != 0
  end

  # Returns true if the credential is currently backed up to cloud storage.
  # Only meaningful when +backup_eligible?+ is true.
  #: () -> bool
  def backed_up?
    flags & BACKUP_STATE_FLAG != 0
  end

  # Decodes the COSE public key bytes into an OpenSSL key object.
  # Returns +nil+ when no attested credential data is present (authentication
  # responses).
  #: () -> OpenSSL::PKey::PKey?
  def public_key
    if key_bytes = public_key_bytes
      @public_key ||= ActionPack::WebAuthn::CoseKey.decode(key_bytes).to_openssl_key
    end
  end
end
