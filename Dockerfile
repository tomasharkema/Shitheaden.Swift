FROM swift:5.5

COPY Package.swift ./Package.swift
COPY Sources ./Sources

RUN swift build -c release
