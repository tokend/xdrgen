# Running OpenAPI generator

## Preparation:
1. Run `bundle install` in the root of repository to install all dependencies;
2. Build xdrgen gem. Run `gem build xdrgen.gemspec`;
3. Install xdrgen gem. Run `[sudo] gem install xdrgen-0.0.6.gem`
4. Put xdr files to `xdr` directory in the root of xdrgen.

## Running:
Run `rake generate openapi` in the root of xdrgen. Resulting file will be xdr/xdr_openapi_generated.yaml

