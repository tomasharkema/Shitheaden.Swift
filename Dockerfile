FROM docker.harkema.io/swift-5.5:1804 as builder

#FROM docker.harkema.io/swift-main:1804 as builder

WORKDIR /app

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

# RUN swift build --product NIOSSH

COPY Package.swift ./Package.swift
COPY Sources ./Sources

RUN swift build -v -c release


FROM docker.harkema.io/swift-5.5:1804-slim
#FROM docker.harkema.io/swift-main:1804

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/.build/release/shitheaden /app/.build/release/shitheaden

ENTRYPOINT /app/.build/release/shitheaden
