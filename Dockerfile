FROM tomasharkema7/swift-5.5:1804 as builder

WORKDIR /app

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

# RUN swift build --product NIOSSH

COPY lib/Package.swift ./Package.swift
COPY lib/Sources ./Sources
COPY lib/Tests ./Tests
RUN find Sources -type f -exec md5sum {} \; | sort -k 2 | md5sum > lib.sig

RUN swift build -v -c release

FROM tomasharkema7/swift-5.5:1804

RUN apt-get update -y && apt-get install -y git curl libatomic1 libxml2 netcat-openbsd lsof perl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/.build/release/shitheaden /app/shitheaden
COPY --from=builder /app/lib.sig /app/lib.sig

ENTRYPOINT /app/shitheaden

CMD [ "/app/shitheaden", "--server" ]