// Copyright 2019 Oath Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
package com.yahoo.test.servlet;

import com.yahoo.test.InjectedComponent;

import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.ServletException;
import java.io.IOException;
import java.lang.Override;

public class ServletWithComponentInjection extends HttpServlet {
    private final InjectedComponent myComponent;

    public ServletWithComponentInjection(InjectedComponent myComponent) {
        this.myComponent = myComponent;
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {
        response.getWriter().write(myComponent.getResult());
    }
}
