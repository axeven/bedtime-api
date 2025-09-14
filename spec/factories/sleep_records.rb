FactoryBot.define do
  factory :sleep_record do
    association :user
    bedtime { 2.hours.ago }
    wake_time { nil }
    duration_minutes { nil }

    trait :completed do
      wake_time { 1.hour.ago }
      duration_minutes { 60 }
    end

    trait :active do
      wake_time { nil }
      duration_minutes { nil }
    end

    trait :overnight do
      bedtime { Time.parse('23:30:00') }
      wake_time { Time.parse('07:15:00') + 1.day }
      duration_minutes { 465 }
    end
  end
end