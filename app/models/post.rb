class Post < ApplicationRecord
  belongs_to :user

  validates :content, presence: true

  before_save :calculate_word_count

  private
  # TODO: improve this
  def calculate_word_count
    self.word_count = content.split.size
  end
end
