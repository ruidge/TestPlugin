package com.example.plugin;

import org.gradle.api.Plugin;
import org.gradle.api.Project;

public class TestPlugin implements Plugin<Project> {
    @Override
    public void apply(Project project) {
        System.out.println("this is CusPlugin");
    }

}
