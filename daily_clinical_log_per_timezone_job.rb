class DailyClinicalLogPerTimezoneJob
  include Sidekiq::Job

  def perform(timezone)
    Time.use_zone(timezone) do
      today_date = Time.zone.today
      facilities = Facility.active.where(time_zone: timezone)

      ClinicalLog.daily_recuring.where(facility: facilities).find_each do |log|
        ActsAsTenant.with_tenant(log.facility.tenant) do
          # Senstive details are hidden
        end
      end
    end
  end
end
