class Tenant < ApplicationRecord
## Associations
  has_many :users, dependent: :destroy
  has_many :companies, dependent: :destroy
  has_many :jobs, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :facilities, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :clinical_log_reports, dependent: :destroy

## Scopes
  scope :not_admin, -> { where.not(subdomain: 'admin') }
  scope :not_admin_or_biomedix, -> { where.not(subdomain: ['admin', 'portal']) }
  scope :portal, -> { where(subdomain: 'portal').first }
  scope :admin,  -> { where(subdomain: 'admin').first }

## Attributes

## Validations
  validates :name, :subdomain, presence: true, uniqueness: true
  validate :no_special_characters_in_subdomain
  validate :default_tenant_subdomains_cannot_change

  ## Instance Methods
  # Sensitive details are hidden
end