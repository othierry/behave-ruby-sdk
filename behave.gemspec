Gem::Specification.new do |s|
  s.name        = 'behave'
  s.version     = '0.0.1'
  s.date        = '2014-02-28'
  s.summary     = "Behave Ruby SDK"
  s.description = "Behave SDK for ruby integration"
  s.authors     = ["Olivier Thierry"]
  s.email       = 'olivier@behave.io'
  s.files       = ["lib/behave.rb"]
  s.homepage    =
    'http://behave.io'
  s.license       = 'MIT'

  # Dependencies
  s.add_runtime_dependency 'httparty'
end