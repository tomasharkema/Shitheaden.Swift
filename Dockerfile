FROM docker.harkema.io/swift-5.5
WORKDIR /app
COPY Package.swift ./Package.swift
COPY Sources ./Sources

RUN swift build -c release -v


