require 'spec_helper'

describe Sorted::Parser, "params parsing" do
  it "should not raise if pased nil arguments" do
    lambda { Sorted::Parser.new(nil, nil).toggle }.should_not raise_error
  end

  it "should return a nice array from the order sql" do
    sort   = nil
    order  = "email ASC, phone ASC, name DESC"
    result = [["email", "asc"], ["phone", "asc"], ["name", "desc"]]

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.orders.should eq result
  end

  it "should return a nice array from the sort params" do
    sort   = "email_desc!name_desc"
    order  = nil
    result = [["email", "desc"], ["name", "desc"]]

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.sorts.should eq result
  end

  it "should combine sort and order params with sort params being of higer importance" do
    sort   = "email_desc!name_desc"
    order  = "email ASC, phone ASC, name DESC"
    result = [["email", "desc"], ["name", "desc"], ["phone", "asc"]]

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.to_a.should eq result
  end

  it "should allow numbers, underscores and full stops in sort params" do
    sort   = "assessmentsTable.name_desc!users_300.name_5_desc"
    order  = nil
    result = [["assessmentsTable.name", "desc"], ["users_300.name_5", "desc"]]

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.sorts.should eq result
  end

  it "should allow numbers, underscores and full stops in order params" do
    sort   = nil
    order  = "assessmentsTable.name ASC, users_300.name_5 ASC"
    result = [["assessmentsTable.name", "asc"], ["users_300.name_5", "asc"]]

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.orders.should eq result
  end

  it "should default to asc if sort params order is ommited" do
    sort   = nil
    order  = :email
    result = [["email", "asc"]]

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.orders.should eq result
  end

  it "should filtered by a whitelist" do
    sort   = "email_desc!name_desc"
    order  = "email ASC, phone ASC, name DESC"
    result = [["email", "desc"], ["name", "desc"]]

    sorter = Sorted::Parser.new(sort, order, ["name", "email"])
    sorter.to_a.should eq result
  end

  it "should filtered by a whitelist even if they have table names" do
    sort   = "group.email_desc!name_desc"
    order  = "group.email ASC, address.phone ASC, user.name DESC"
    result = [["group.email", "desc"], ["user.name", "desc"]]

    sorter = Sorted::Parser.new(sort, order, ["user.name", "group.email", "phone"])
    sorter.to_a.should eq result
  end

  it "should call the logger if any field filtered by a whitelist" do
    logged = []
    logger = -> (msg) { logged << msg }
    sort   = "group.email_desc!name_desc"
    order  = "group.email ASC, address.phone ASC, user.name DESC"
    result = ["Unpermitted sort field: name desc", "Unpermitted sort field: address.phone asc"]

    _sql = Sorted::Parser.new(sort, order, ["user.name", "group.email", "phone"], {}, logger).to_sql
    logged.should eq result
  end

  it "should create a customized SQL if a customlist is given" do
    sort   = "group.email_asc!name_desc"
    order  = "group.email DESC, address.phone ASC, user.name DESC"
    custom = { "group.email asc" => "group.email IS NOT NULL ASC, group.email ASC" }
    result = "group.email IS NOT NULL ASC, group.email ASC, name DESC, address.phone ASC, user.name DESC"

    sorter = Sorted::Parser.new(sort, order, nil, custom)
    sorter.to_sql.should eq result
  end
end

describe Sorted::Parser, "return types" do
  module FakeConnection
    def self.quote_column_name(column_name)
      "`#{column_name}`"
    end
  end

  let(:quoter) {
    ->(frag) { FakeConnection.quote_column_name(frag) }
  }

  it "should properly escape sql column names" do
    order = "users.name DESC"
    result = "`users`.`name` DESC"

    sorter = Sorted::Parser.new(nil, order, nil)
    sorter.to_sql(quoter).should eq result
  end

  it "should return an sql sort string" do
    sort   = "email_desc!name_desc"
    order  = "email ASC, phone ASC, name DESC"
    result = "`email` DESC, `name` DESC, `phone` ASC"

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.to_sql(quoter).should eq result
  end

  it "should return an hash" do
    sort   = "email_desc!name_desc"
    order  = "email ASC, phone ASC, name DESC"
    result = {"email" => "desc", "name" => "desc", "phone" => "asc"}

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.to_hash.should eq result
  end

  it "should return an the encoded sort string" do
    sort   = "email_desc!name_desc"
    order  = "email ASC, phone ASC, name DESC"
    result = "email_desc!name_desc!phone_asc"

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.to_s.should eq result
  end

  it "sql injection using order by clause should not work" do
    sort   = "(case+when+((ASCII(SUBSTR((select+table_name+from+all_tables+where+rownum%3d1),1))>%3D128))+then+id+else+something+end)"
    order  = "email ASC, phone ASC, name DESC"
    result = "`email` ASC, `phone` ASC, `name` DESC"

    sorter = Sorted::Parser.new(sort, order, nil)
    sorter.to_sql(quoter).should eq result
  end
end

describe Sorted::Parser, "initialize_whitelist" do
  it "should generate a whitelist from models and strings" do
    sourcelist = ["name", "group.email", Struct.new(:table_name, :column_names).new("faketable", ["field1", "field2"])]
    result = ["name", "group.email", "faketable.field1", "field1", "faketable.field2", "field2"]

    expect(Sorted::Parser.send(:initialize_whitelist, sourcelist)).to eq result
  end

  it "should generate a whitelist with table names if fields are ambiguous" do
    sourcelist =
      ["name", "group.email", # Actually the "name" should not be specified; it's ambiguous anyway
       Struct.new(:table_name, :column_names).new("faketable", ["name", "field1", "field2"]),
       Struct.new(:table_name, :column_names).new("faketable2", ["email", "field1", "otherfield"]) ]
    result =
      ["name", "group.email",
       "faketable.name", "faketable.field1", "faketable.field2", "field2",
       "faketable2.email", "faketable2.field1", "faketable2.otherfield", "otherfield"]

    expect(Sorted::Parser.send(:initialize_whitelist, sourcelist)).to eq result
  end
end
