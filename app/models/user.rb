class User < ApplicationRecord
  has_secure_password
  has_many :posts, dependent: :destroy
  has_many :sessions, dependent: :destroy

  # Normalize identity fields so lookups and uniqueness are not defeated by
  # casing or stray whitespace. Email is matched case-insensitively; usernames
  # are kept case-sensitive (only surrounding whitespace is trimmed).
  normalizes :email, with: ->(email) { email.to_s.strip.downcase }
  normalizes :username, with: ->(username) { username.to_s.strip }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    length: { maximum: 255 }
  validates :username, presence: true, uniqueness: true, length: { maximum: 30 }
  # Minimum 8; maximum 72 because bcrypt silently truncates input beyond 72
  # bytes, so anything longer would not actually be verified in full.
  validates :password, presence: true, length: { minimum: 8, maximum: 72 }, on: :create
end
