require_relative "lib/wulin_queue/version"

Gem::Specification.new do |s|
  s.name = "wulin_queue"
  s.version = WulinQueue::VERSION
  s.authors = ["Ekohe"]
  s.email = ["dev@ekohe.com"]
  s.homepage = "https://gitlab.ekohe.com/ekohe/wulin/wulin_queue"
  s.summary = "Solid Queue screens for WulinMaster"
  s.description = "Solid Queue screens for WulinMaster"
  s.license = "MIT"

  s.files = `git ls-files`.split("\n")
  s.require_paths = ["lib"]

  s.required_ruby_version = ">= 3.4"

  s.add_dependency "rails", ">= 8.1"
  s.add_dependency "solid_queue", "~> 1.4"

  s.add_development_dependency "standard"
  s.add_development_dependency "minitest"
  s.add_development_dependency "sqlite3"
end
