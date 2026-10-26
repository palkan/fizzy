# typed: true

module MagicLink::Code
  CODE_SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

  def self.generate(length)
    SecureRandom.base32(length)
  end

  def self.sanitize(code)
    if code.present?
      normalize_code(code)
        .then { apply_substitutions(it) }
        .then { remove_invalid_characters(it) }
    end
  end

  private_class_method def self.normalize_code(code)
    code.to_s.upcase
  end

  private_class_method def self.apply_substitutions(code)
    CODE_SUBSTITUTIONS.reduce(code) { |result, (from, to)| result.gsub(from, to) }
  end

  private_class_method def self.remove_invalid_characters(code)
    code.gsub(/[^#{SecureRandom::BASE32_ALPHABET.join}]/, "")
  end
end
