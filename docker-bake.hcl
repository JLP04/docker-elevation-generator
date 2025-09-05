target "default" {
    description = "The main target to build for all architectures"
    tags = ["ghcr.io/jlp04/elevation-generator"]
    args = {
      "branch_end" = null
    }
    cache-from = [ "type=gha" ]
    cache-to = [ "type=gha,mode=max" ]
    attest = [
        {
            type="provenance"
            mode="max"
        },
        {
            type="sbom"
        }
    ]
    platforms=["linux/386", "linux/amd64", "linux/arm/v5", "linux/arm/v7", "linux/arm64/v8", "linux/ppc64le", "linux/riscv64", "linux/s390x"]
}

target "validate-build" {
    inherits = ["default"]
    call = "check"
}