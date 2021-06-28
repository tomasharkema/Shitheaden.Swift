FROM tomasharkema7/swift-5.5:1804-snapshot as builder

WORKDIR /app

RUN apt-get update -y && \
    apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && \
    rm -rf /var/lib/apt/lists/*

# RUN swift build --product NIOSSH

RUN mkdir -p ./Sources/CustomAlgo && \
    touch ./Sources/CustomAlgo/main.swift && \
    mkdir -p ./Sources/ShitheadenRuntime && \
    touch ./Sources/ShitheadenRuntime/main.swift && \
    mkdir -p ./Sources/ShitheadenServer && \
    touch ./Sources/ShitheadenServer/main.swift && \
    mkdir -p ./Sources/ShitheadenCLIRenderer && \
    touch ./Sources/ShitheadenCLIRenderer/main.swift && \
    mkdir -p ./Sources/ShitheadenShared && \
    touch ./Sources/ShitheadenShared/main.swift && \
    mkdir -p ./Sources/ShitheadenCLI && \
    touch ./Sources/ShitheadenCLI/main.swift && \
    mkdir -p ./Tests/ShitheadenRuntimeTests && \
    touch ./Tests/ShitheadenRuntimeTests/main.swift && \
    mkdir -p ./Tests/ShitheadenSharedTests && \
    touch ./Tests/ShitheadenSharedTests/main.swift && \
    mkdir -p ./Tests/CustomAlgoTests && \
    touch ./Tests/CustomAlgoTests/main.swift 

COPY lib/Package.swift ./Package.swift

COPY lib/Sources/DependenciesTarget ./Sources/DependenciesTarget
COPY lib/Sources/AppDependencies ./Sources/AppDependencies

RUN swift build --target DependenciesTarget -v -c release

RUN rm ./Sources/CustomAlgo/main.swift && \
    rm ./Sources/ShitheadenRuntime/main.swift && \
    rm ./Sources/ShitheadenShared/main.swift && \
    rm ./Sources/ShitheadenCLI/main.swift && \
    rm ./Sources/ShitheadenCLIRenderer/main.swift && \
    rm ./Sources/ShitheadenServer/main.swift && \
    rm ./Tests/CustomAlgoTests/main.swift 

COPY lib/Sources ./Sources
COPY lib/Tests ./Tests

RUN find Sources/ShitheadenRuntime Sources/ShitheadenShared -type f -exec shasum -a 256 {} \; | sort -k 2 | shasum -a 256 > lib.sig

RUN swift build -v -c release

FROM tomasharkema7/swift-5.5:1804-snapshot

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/.build/release/ShitheadenServer /app/ShitheadenServer
COPY --from=builder /app/lib.sig /app/lib.sig

ENTRYPOINT /app/ShitheadenServer

CMD [ "/app/ShitheadenServer" ]