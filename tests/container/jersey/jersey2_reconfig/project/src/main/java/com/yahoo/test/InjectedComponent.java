// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test;

public class InjectedComponent {

    public final String message;

    public InjectedComponent(MessageConfig config) {
        message = config.message();
    }
}
