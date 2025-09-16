FactoryBot.define do
  factory :sleep_record do
    association :user
    sequence(:bedtime) { |n| n.days.ago }
    wake_time { nil }
    duration_minutes { nil }

    trait :completed do
      sequence(:bedtime) { |n| n.days.ago.beginning_of_day + 22.hours }
      sequence(:wake_time) { |n| (n - 1).days.ago.beginning_of_day + 6.hours }
      duration_minutes { 480 }
    end

    trait :active do
      bedtime { 2.hours.ago }
      wake_time { nil }
      duration_minutes { nil }
    end

    trait :overnight do
      sequence(:bedtime) { |n| n.days.ago.beginning_of_day + 23.hours + 30.minutes }
      sequence(:wake_time) { |n| (n - 1).days.ago.beginning_of_day + 7.hours + 15.minutes }
      duration_minutes { 465 }
    end
  end
end
