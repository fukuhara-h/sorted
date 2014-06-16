# sorted

[![Build Status](https://travis-ci.org/mynameisrufus/sorted.png?branch=master)](https://travis-ci.org/mynameisrufus/sorted)

Sorted is a simple object that will take an sql order string and a url
sort string to let you sort large datasets over many pages (using 
[will_paginate](https://github.com/mislav/will_paginate) or 
[kaminari](https://github.com/amatsuda/kaminari)) without losing state.

### View

Generate a sorted link with the email attribute:

```ruby
link_to_sorted "Email", :email
```

Works the same as the `link_to` method except a second argument for the
sort attribute is needed.

### Ruby 1.8.7 Rails 3.x

```ruby
gem 'sorted', '~> 0.4.3'
```

### Model

Using the `sorted` method with the optional default order argument. The third argument is column names that the `ORDER BY` clause can use.

```ruby
@users = User.sorted(params[:sort], "email ASC", ["email", "name"]).page(params[:page])
```

You can also specify ActiveRecord models to the third argument. All columns of the models will be added to the whitelist. In order to get column names it will use `table_name` and `column_names` methods.

### Rubies

* MRI 1.9.3, 2.0.0.
* JRuby 1.9 mode

### ORMs

* ActiveRecord
* Mongoid
