require 'xdrgen'
require "bundler/gem_tasks"

task :clean do
  system("rm -rf ./gen")
end

task :generate do
  task :openapi do
    paths = Pathname.glob("xdr/*.x")
    compilation = Xdrgen::Compilation.new(
      paths,
      output_dir: "xdr",
      namespace:  "xdr",
      language:   :openapi
    )
    compilation.compile
  end
end

