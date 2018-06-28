# SitePrism iFrame Demo project

In order to investigate https://github.com/natritmeyer/site_prism/issues/274
I set up the project as minimalistic as possible with the same environment
(e.g. using chromedriver) and page/section structure as it is in the main app.

## Installation

As usual:
1. clone it
2. Run `bundle install`

## Let The Test Fail

Running

```
bundle exec rspec
```

starts the one selenium test that happily breaks with the exact same error message.
