unit class CITestSetManager;

use Log::Async;

use SerialDedup;
use DB;
use SourceArchiveCreator;
use Config;
use Red::Operators:api<2>;


has SetHash $!status-listeners .= new;
has SetHash $!test-set-listeners .= new;
has $!source-archive-creator is built is required;

method register-status-listener($status-listener) {
    $!status-listeners.set: $status-listener;
}

method register-test-set-listener($test-set-listener) {
    $!test-set-listeners.set: $test-set-listener;
}

method process-worklist() is serial-dedup {
    for DB::CITestSet.^all.grep(
      *.status ⊂ (DB::UNPROCESSED, DB::SOURCE_ARCHIVE_CREATED, DB::WAITING_FOR_TEST_RESULTS))
      -> $test-set {
        given $test-set.status {
            when DB::UNPROCESSED {
                trace "CITestSetManager: processing unprocessed " ~ $test-set.id;
                my $id = $!source-archive-creator.create-archive($test-set.source-spec);
                $test-set.source-archive-id = $id;
                $test-set.status = DB::SOURCE_ARCHIVE_CREATED;
                $test-set.^save;
                proceed;

                CATCH {
                    when X::ArchiveCreationException {
                        warn "ArchiveCreationException: " ~ $_.message;

                        if ++$test-set.source-retrieval-retries > config.github-max-source-retrieval-retries {
                            $test-set.status = DB::ERROR;
                            warn "Now giving up retrieving the source archive: " ~ $test-set.id;
                        }
                        $test-set.^save;
                    }
                }
            }
            when DB::SOURCE_ARCHIVE_CREATED {
                trace "CITestSetManager: processing source_archive_created " ~ $test-set.id;
                for $!test-set-listeners.keys {
                    $_.new-test-set($test-set)
                }
                $test-set.status = DB::WAITING_FOR_TEST_RESULTS;
                $test-set.^save;
            }
            when DB::WAITING_FOR_TEST_RESULTS {
                # TODO Check if all tests are done
            }
        }
    }

    CATCH {
        default {
            error "Failed starting OBS run: " ~ .message ~ .backtrace.Str
        }
    }
}

method add-test-set(:$test-set!, :$source-spec!) {
    $test-set.status = DB::UNPROCESSED;
    $test-set.source-spec: $source-spec;
    $test-set.^save;
    self.process-worklist;
}

method add-tests(*@tests) {
    $_.tests-queued(@tests) for $!status-listeners.keys;
}

method test-status-updated($test) {
    $_.test-status-changed($test) for $!status-listeners.keys;
}

method platform-test-set-done($platform-test-set) {
    my $test-set = $platform-test-set.test-set;
    if [&&] $test-set.platform-test-sets.map(*.status == DB::PLATFORM_DONE) {
        $_.test-set-done($test-set) for $!status-listeners.keys;
        $test-set.status = DB::DONE;
        $test-set.^save;
    }
}

