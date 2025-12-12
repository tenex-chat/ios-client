//
//  Tuist.swift
//  TENEX
//

import ProjectDescription

let config = Config(
    compatibleXcodeVersions: .all,
    swiftVersion: "6.0",
    generationOptions: .options(
        enforceExplicitDependencies: true,
        defaultConfiguration: "Debug"
    )
)
