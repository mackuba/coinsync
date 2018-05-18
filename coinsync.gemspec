# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'coinsync/version'

Gem::Specification.new do |spec|
  spec.name          = "coinsync"
  spec.version       = CoinSync::VERSION
  spec.authors       = ["Kuba Suder"]
  spec.email         = ["jakub.suder@gmail.com"]

  spec.summary       = "A tool for importing and processing data from cryptocurrency exchanges"
  spec.homepage      = "https://github.com/mackuba/coinsync"
  spec.license       = "MIT"

  spec.files         = ['MIT-LICENSE.txt', 'README.md'] + Dir['lib/**/*'] + Dir['doc/**/*']

  spec.bindir        = "bin"
  spec.executables   = Dir['bin/*'].map { |f| File.basename(f) } - ['console', 'setup']

  spec.add_dependency 'cri', '~> 2.10'
  spec.add_dependency 'tzinfo', '>= 1.2.5', '< 2.0'
end
