class DailyClinicalLogJob
  include Sidekiq::Job

  def perform
    timezones = Facility.active.pluck(:time_zone).map { |tz| tz.presence || Rails.application.config.time_zone }.uniq

    Facility.all.each do |f|
      dt = Time.now.in_time_zone.in_time_zone(f.time_zone).to_date
      f.facility_open_statuses.create(effective_date: dt, status: '') if f.facility_open_statuses.find_by(effective_date: dt).blank?
    end

    timezones.each do |tz|
      Time.use_zone(tz) do
        next unless [1].include?(Time.zone.now.hour)
        DailyClinicalLogPerTimezoneJob.perform_async(tz)
      end
    end
  end
end
