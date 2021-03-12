package com.gradle;

import com.gradle.scan.plugin.BuildScanExtension;

import org.gradle.api.Action;
import org.gradle.api.Project;
import org.gradle.api.Task;
import org.gradle.api.invocation.Gradle;
import org.gradle.api.tasks.testing.Test;

import java.util.Optional;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.gradle.Utils.*;

/**
 * Adds a standard set of useful tags, links and custom values to all build scans published.
 */
final class CustomBuildScanEnhancements {

    static void configureBuildScan(BuildScanExtension buildScan, Gradle gradle) {
        new CustomBuildScanEnhancer(buildScan, gradle).enhance();
    }

    private static class CustomBuildScanEnhancer {
        private final BuildScanExtension buildScan;
        private final Gradle gradle;

        private CustomBuildScanEnhancer(BuildScanExtension buildScan, Gradle gradle) {
            this.buildScan = buildScan;
            this.gradle = gradle;
        }

        private Optional<String> projectProperty(String name) {
            String value = (String) gradle.getRootProject().findProperty(name);
            return Optional.ofNullable(value);
        }

        public void enhance() {
            captureOs();
            captureIde();
            captureCiOrLocal();
            captureCiMetadata();
            captureGitMetadata();
            captureTestParallelization();
        }

        private void captureOs() {
            sysProperty("os.name").ifPresent(buildScan::tag);
        }

        private void captureIde() {
            // Wait for projects to load to ensure Gradle project properties are initialized
            gradle.projectsEvaluated(g -> {
                Project project = g.getRootProject();
                if (project.hasProperty("android.injected.invoked.from.ide")) {
                    buildScan.tag("Android Studio");
                    if (project.hasProperty("android.injected.studio.version")) {
                        buildScan.value("Android Studio version", String.valueOf(project.property("android.injected.studio.version")));
                    }
                } else if (sysProperty("idea.version").isPresent() || sysPropertyKeyStartingWith("idea.version")) {
                    buildScan.tag("IntelliJ IDEA");
                } else if (sysProperty("eclipse.buildId").isPresent()) {
                    buildScan.tag("Eclipse");
                } else if (!isCi()) {
                    buildScan.tag("Cmd Line");
                }
            });
        }

        private void captureCiOrLocal() {
            buildScan.tag(isCi() ? "CI" : "LOCAL");
        }

        private void captureCiMetadata() {
            if (isJenkins() || isHudson()) {
                envVariable("BUILD_URL").ifPresent(url ->
                        buildScan.link(isJenkins() ? "Jenkins build" : "Hudson build", url));
                envVariable("BUILD_NUMBER").ifPresent(value ->
                        buildScan.value("CI build number", value));
                envVariable("NODE_NAME").ifPresent(value2 ->
                        addCustomValueAndSearchLink("CI node", value2));
                envVariable("JOB_NAME").ifPresent(value1 ->
                        addCustomValueAndSearchLink("CI job", value1));
                envVariable("STAGE_NAME").ifPresent(value ->
                        addCustomValueAndSearchLink("CI stage", value));
            }

            if (isTeamCity()) {
                // Wait for projects to load to ensure Gradle project properties are initialized
                gradle.projectsEvaluated(g -> {
                    Optional<String> teamCityConfigFile = projectProperty("teamcity.configuration.properties.file");
                    Optional<String> buildNumber = projectProperty("build.number");
                    Optional<String> buildTypeId = projectProperty("teamcity.buildType.id");
                    Optional<String> agentName = projectProperty("agent.name");
                    if (teamCityConfigFile.isPresent()
                            && buildNumber.isPresent()
                            && buildTypeId.isPresent()) {
                        Properties properties = readPropertiesFile(teamCityConfigFile.get());
                        String teamCityServerUrl = properties.getProperty("teamcity.serverUrl");
                        if (teamCityServerUrl != null) {
                            String buildUrl = appendIfMissing(teamCityServerUrl, "/") + "viewLog.html?buildNumber=" + buildNumber.get() + "&buildTypeId=" + buildTypeId.get();
                            buildScan.link("TeamCity build", buildUrl);
                        }
                    }
                    buildNumber.ifPresent(value ->
                            buildScan.value("CI build number", value));
                    agentName.ifPresent(value ->
                            addCustomValueAndSearchLink("CI agent", value));

                });
            }

            if (isCircleCI()) {
                envVariable("CIRCLE_BUILD_URL").ifPresent(url ->
                        buildScan.link("CircleCI build", url));
                envVariable("CIRCLE_BUILD_NUM").ifPresent(value ->
                        buildScan.value("CI build number", value));
                envVariable("CIRCLE_JOB").ifPresent(value1 ->
                        addCustomValueAndSearchLink("CI job", value1));
                envVariable("CIRCLE_WORKFLOW_ID").ifPresent(value ->
                        addCustomValueAndSearchLink("CI workflow", value));
            }

            if (isBamboo()) {
                envVariable("bamboo_resultsUrl").ifPresent(url ->
                        buildScan.link("Bamboo build", url));
                envVariable("bamboo_buildNumber").ifPresent(value ->
                        buildScan.value("CI build number", value));
                envVariable("bamboo_planName").ifPresent(value2 ->
                        addCustomValueAndSearchLink("CI plan", value2));
                envVariable("bamboo_buildPlanName").ifPresent(value1 ->
                        addCustomValueAndSearchLink("CI build plan", value1));
                envVariable("bamboo_agentId").ifPresent(value ->
                        addCustomValueAndSearchLink("CI agent", value));
            }

            if (isGitHubActions()) {
                Optional<String> gitHubRepository = envVariable("GITHUB_REPOSITORY");
                Optional<String> gitHubRunId = envVariable("GITHUB_RUN_ID");
                if (gitHubRepository.isPresent() && gitHubRunId.isPresent()) {
                    buildScan.link("GitHub Actions build", "https://github.com/" + gitHubRepository.get() + "/actions/runs/" + gitHubRunId.get());
                }
                envVariable("GITHUB_WORKFLOW").ifPresent(value ->
                        addCustomValueAndSearchLink("GitHub workflow", value));
            }

            if (isGitLab()) {
                envVariable("CI_JOB_URL").ifPresent(url1 ->
                        buildScan.link("GitLab build", url1));
                envVariable("CI_PIPELINE_URL").ifPresent(url ->
                        buildScan.link("GitLab pipeline", url));
                envVariable("CI_JOB_NAME").ifPresent(value1 ->
                        addCustomValueAndSearchLink("CI job", value1));
                envVariable("CI_JOB_STAGE").ifPresent(value ->
                        addCustomValueAndSearchLink("CI stage", value));
            }

            if (isTravis()) {
                envVariable("TRAVIS_BUILD_WEB_URL").ifPresent(url ->
                        buildScan.link("Travis build", url));
                envVariable("TRAVIS_BUILD_NUMBER").ifPresent(value ->
                        buildScan.value("CI build number", value));
                envVariable("TRAVIS_JOB_NAME").ifPresent(value ->
                        addCustomValueAndSearchLink("CI job", value));
                envVariable("TRAVIS_EVENT_TYPE").ifPresent(buildScan::tag);
            }

            if (isBitrise()) {
                envVariable("BITRISE_BUILD_URL").ifPresent(url ->
                        buildScan.link("Bitrise build", url));
                envVariable("BITRISE_BUILD_NUMBER").ifPresent(value ->
                        buildScan.value("CI build number", value));
            }
        }

        private static boolean isCi() {
            return isGenericCI() || isJenkins() || isHudson() || isTeamCity() || isCircleCI() || isBamboo() || isGitHubActions() || isGitLab() || isTravis() || isBitrise();
        }

        private static boolean isGenericCI() {
            return envVariable("CI").isPresent() || sysProperty("CI").isPresent();
        }

        private static boolean isJenkins() {
            return envVariable("JENKINS_URL").isPresent();
        }

        private static boolean isHudson() {
            return envVariable("HUDSON_URL").isPresent();
        }

        private static boolean isTeamCity() {
            return envVariable("TEAMCITY_VERSION").isPresent();
        }

        private static boolean isCircleCI() {
            return envVariable("CIRCLE_BUILD_URL").isPresent();
        }

        private static boolean isBamboo() {
            return envVariable("bamboo_resultsUrl").isPresent();
        }

        private static boolean isGitHubActions() {
            return envVariable("GITHUB_ACTIONS").isPresent();
        }

        private static boolean isGitLab() {
            return envVariable("GITLAB_CI").isPresent();
        }

        private static boolean isTravis() {
            return envVariable("TRAVIS_JOB_ID").isPresent();
        }

        private static boolean isBitrise() {
            return envVariable("BITRISE_BUILD_URL").isPresent();
        }

        private void captureGitMetadata() {
            buildScan.background(api -> {
                if (!isGitInstalled()) {
                    return;
                }

                String gitCommitId = execAndGetStdOut("git", "rev-parse", "--short=8", "--verify", "HEAD");
                String gitBranchName = execAndGetStdOut("git", "rev-parse", "--abbrev-ref", "HEAD");
                String gitStatus = execAndGetStdOut("git", "status", "--porcelain");

                if (gitCommitId != null) {
                    addCustomValueAndSearchLink("Git commit id", gitCommitId);

                    String originUrl = execAndGetStdOut("git", "config", "--get", "remote.origin.url");
                    if (isNotEmpty(originUrl)) {
                        if (originUrl.contains("github.com/") || originUrl.contains("github.com:")) {
                            Matcher matcher = Pattern.compile("(.*)github\\.com[/|:](.*)").matcher(originUrl);
                            if (matcher.matches()) {
                                String rawRepoPath = matcher.group(2);
                                String repoPath = rawRepoPath.endsWith(".git") ? rawRepoPath.substring(0, rawRepoPath.length() - 4) : rawRepoPath;
                                api.link("Github source", "https://github.com/" + repoPath + "/tree/" + gitCommitId);
                            }
                        } else if (originUrl.contains("gitlab.com/") || originUrl.contains("gitlab.com:")) {
                            Matcher matcher = Pattern.compile("(.*)gitlab\\.com[/|:](.*)").matcher(originUrl);
                            if (matcher.matches()) {
                                String rawRepoPath = matcher.group(2);
                                String repoPath = rawRepoPath.endsWith(".git") ? rawRepoPath.substring(0, rawRepoPath.length() - 4) : rawRepoPath;
                                api.link("GitLab Source", "https://gitlab.com/" + repoPath + "/-/commit/" + gitCommitId);
                            }
                        }
                    }
                }
                if (isNotEmpty(gitBranchName)) {
                    api.tag(gitBranchName);
                    api.value("Git branch", gitBranchName);
                }
                if (isNotEmpty(gitStatus)) {
                    api.tag("Dirty");
                    api.value("Git status", gitStatus);
                }
            });
        }

        private static boolean isGitInstalled() {
            return execAndCheckSuccess("git", "--version");
        }

        private void captureTestParallelization() {
            gradle.allprojects(p ->
                    p.getTasks().withType(Test.class).configureEach(test ->
                            test.doFirst(new Action<Task>() {
                                // use anonymous inner class to keep Test task instance cacheable
                                @Override
                                public void execute(Task task) {
                                    buildScan.value(test.getIdentityPath() + "#maxParallelForks", String.valueOf(test.getMaxParallelForks()));
                                }
                            })
                    )
            );
        }

        private void addCustomValueAndSearchLink(String label, String value) {
            buildScan.value(label, value);
            String server = buildScan.getServer();
            if (server != null) {
                String searchParams = "search.names=" + urlEncode(label) + "&search.values=" + urlEncode(value);
                String url = appendIfMissing(server, "/") + "scans?" + searchParams + "#selection.buildScanB=" + urlEncode("{SCAN_ID}");
                buildScan.link(label + " build scans", url);
            }
        }
    }

    private CustomBuildScanEnhancements() {
    }

}