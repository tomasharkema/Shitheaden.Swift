FROM tomasharkema7/swift-5.5:1804 as builder

WORKDIR /app

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

# RUN swift build --product NIOSSH

COPY lib/Package.swift ./Package.swift
COPY lib/Sources ./Sources
COPY lib/Tests ./Tests

RUN swift build -v -c release

FROM tomasharkema7/swift-5.5:1804

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/.build/release/shitheaden /app/.build/release/shitheaden

ENTRYPOINT /app/.build/release/shitheaden
