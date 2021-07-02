FROM tomasharkema7/swift-5.5:1804 as builder

WORKDIR /app

RUN apt-get update -y && \
    apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl libssl-dev && \
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
    touch ./Tests/CustomAlgoTests/main.swift  && \
    mkdir -p ./Sources/TestsHelpers && \
    touch ./Sources/TestsHelpers/main.swift 

COPY lib/Package.swift ./Package.swift

COPY lib/Sources/AppDependencies ./Sources/AppDependencies

RUN swift package resolve

RUN swift build --target Vapor -c release
RUN swift build --target NIOSSH -c release
RUN swift build --target ArgumentParser -c release
RUN swift build --target ANSIEscapeCode -c release
RUN swift build --target Logging -c release

RUN rm ./Sources/CustomAlgo/main.swift && \
    rm ./Sources/ShitheadenRuntime/main.swift && \
    rm ./Sources/ShitheadenShared/main.swift && \
    rm ./Sources/ShitheadenCLI/main.swift && \
    rm ./Sources/ShitheadenCLIRenderer/main.swift && \
    rm ./Sources/ShitheadenServer/main.swift && \
    rm ./Tests/CustomAlgoTests/main.swift  && \
    rm .//Sources/TestsHelpers/main.swift 

COPY lib/Sources ./Sources
COPY lib/Tests ./Tests

RUN find Sources/ShitheadenRuntime Sources/ShitheadenShared -type f -exec shasum -a 256 {} \; | sort -k 2 | shasum -a 256 > lib.sig

RUN swift build -c release

FROM tomasharkema7/swift-5.5:1804

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY lib/Public ./Public
COPY --from=builder /app/.build/release/ShitheadenServer /app/ShitheadenServer
COPY --from=builder /app/lib.sig /app/lib.sig

ENTRYPOINT /app/ShitheadenServer

CMD [ "/app/ShitheadenServer" ]