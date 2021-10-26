use YAMLish;

class Config {
    has $.github-app-id;
    has %.projects;

    has $.obs-check-duration;
    has $.obs-min-run-duration;
    has @.obs-packages;

    #| How many latest-changes-PullRequests the GitHub polling logic should retrieve.
    has $.github-pullrequest-check-count;

    has $.sac-work-dir;
    has $.sac-store-dir;
    has $.obs-work-dir;

    has $.testset-manager-interval;
    has $.github-requester-interval;
    has $.obs-interval;

    method from-config(%config) {
        Config.new:
            github-app-id => %config<github-app-id>,
            projects      => %config<projects>,

            obs-check-duration   => %config<obs-check-duration>,
            obs-min-run-duration => %config<obs-min-run-duration>,
            obs-packages         => %config<obs-packages>,

            github-pullrequest-check-count => %config<github-pullrequest-check-count>,

            sac-work-dir  => %config<sac-work-dir>,
            sac-store-dir => %config<sac-store-dir>,
            obs-work-dir  => %config<obs-work-dir>,

            testset-manager-interval  => %config<testset-manager-interval>,
            github-requester-interval => %config<github-requester-interval>,
            obs-interval              => %config<obs-interval>,
        ;
    }
}

my Config $config;
multi set-config(Config $c) is export {
    $config = $c
}

multi set-config(IO::Path $yaml-file) is export {
    set-config(Config.from-config(load-yaml($yaml-file.slurp)));
}

sub config(--> Config) is export {
    $config;
}
