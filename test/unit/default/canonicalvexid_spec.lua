local busted = require 'busted'
local cv = require 'default.canonicalvexid'

describe("canonicalvexid", function()

    it("lowercases all words", function()
        assert.equal("hello-world-1", cv.generate("Hello World", {}))
    end)

    it("strips non-alphanumeric characters from words", function()
        assert.equal("hello-world-1", cv.generate("hello, world!", {}))
    end)

    it("drops filler words", function()
        assert.equal("quick-fox-1", cv.generate("the quick fox", {}))
    end)

    it("drops adverbs ending in -ly", function()
        assert.equal("make-config-control-plugins-1", cv.generate("Make config actually control plugins", {}))
        assert.equal("reply-email-1", cv.generate("Reply quickly to email", {}))
    end)

    it("keeps a single-word description as one word", function()
        assert.equal("refactor-1", cv.generate("Refactor", {}))
    end)

    it("splits words joined by punctuation", function()
        assert.equal("fix-lux-toml-entry-point-1", cv.generate("Fix lux.toml entry point mismatch", {}))
        assert.equal("implement-focus-interpret-1", cv.generate("Implement Focus:interpret", {}))
    end)

    it("keeps only the first of slash-separated alternatives", function()
        assert.equal("fix-union-crashing-cli-1", cv.generate("Fix union/intersect/xor/notin/onlyin crashing from the CLI", {}))
    end)

    it("uses only the first sentence", function()
        assert.equal("create-view-next-up-1", cv.generate("Create view next up. This view shows unblocked tasks, in order of priority.", {}))
    end)

    it("keeps prepositional phrases when there is room", function()
        assert.equal("track-vex-tmp-folder-git-1", cv.generate("Track vex tmp folder in git", {}))
        assert.equal("make-coffee-wife-1", cv.generate("Make coffee for wife", {}))
    end)

    it("drops prepositional phrases before the main clause when over budget", function()
        assert.equal("investigate-login-page-slow-1", cv.generate("Investigate why the login page is slow on mobile", {}))
        assert.equal("fix-numeric-datetime-fields-1", cv.generate("Fix numeric and datetime fields failing validation from the CLI", {}))
    end)

    it("keeps negation", function()
        assert.equal("ensure-verbs-return-data-not-1", cv.generate("Ensure all verbs return data and do not print", {}))
        assert.truthy(cv.generate("Status state machine doesn't reject transitions", {}):find("-not-", 1, true))
    end)

    it("stays within 32 characters and 6 words", function()
        local id = cv.generate("one two three four five six seven eight nine ten eleven", {})
        local tag = id:gsub("%-%d+$", "")
        assert.truthy(#tag <= 32)
        local count = select(2, tag:gsub("[^-]+", ""))
        assert.truthy(count <= 6)
        assert.equal("one-two-three-four-five-six-1", id)
    end)

    it("always takes the first two words even when they are long", function()
        assert.equal("internationalisation-localisation-1", cv.generate("Internationalisation localisation infrastructure", {}))
    end)

    it("falls back to the raw words when everything is filler", function()
        assert.equal("it-is-1", cv.generate("it is", {}))
        assert.equal("task-1", cv.generate("!!!!", {}))
    end)

    it("starts the counter at 1 for a fresh lookup", function()
        assert.equal("hello-world-1", cv.generate("hello world", {}))
    end)

    it("increments the counter when the id already exists", function()
        assert.equal("hello-world-2", cv.generate("hello world", { ["hello-world-1"] = true }))
    end)

    it("keeps incrementing past multiple existing ids", function()
        local lookup = {
            ["hello-world-1"] = true,
            ["hello-world-2"] = true,
            ["hello-world-3"] = true,
        }
        assert.equal("hello-world-4", cv.generate("hello world", lookup))
    end)

end)
