FactoryBot.define do
  factory :follow do
    association :user
    association :following_user, factory: :user
  end
end
