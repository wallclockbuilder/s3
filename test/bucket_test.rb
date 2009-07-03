require 'test_helper'

class BucketTest < Test::Unit::TestCase
  def setup
    @bucket_vhost = S3::Bucket.new(nil, "data-bucket")
    @bucket_path = S3::Bucket.new(nil, "data_bucket")
    @bucket = @bucket_vhost

    @response_location = Net::HTTPOK.new("1.1", "200", "OK")
    stub(@response_location).body { @bucket_location_body }
    @bucket_location = "EU"
    @bucket_location_body = <<-EOLocation
    <?xml version="1.0" encoding="UTF-8"?>\n<LocationConstraint xmlns="http://s3.amazonaws.com/doc/2006-03-01/">EU</LocationConstraint>
    EOLocation

    @reponse_owned_by_you = Net::HTTPConflict.new("1.1", "409", "Conflict")
    stub(@reponse_owned_by_you).body { @bucket_owned_by_you_body }
    @bucket_owned_by_you_body = <<-EOOwnedByYou
    <?xml version="1.0" encoding="UTF-8"?>\n<Error> <Code>BucketAlreadyOwnedByYou</Code> <Message>Your previous request to create the named bucket succeeded and you already own it.</Message> <BucketName>bucket</BucketName> <RequestId>117D08EA0EC6E860</RequestId> <HostId>4VpMSvmJ+G5+DLtVox6O5cZNgdPlYcjCu3l0n4HjDe01vPxxuk5eTAtcAkUynRyV</HostId> </Error>
    EOOwnedByYou

    @reponse_already_exists = Net::HTTPConflict.new("1.1", "409", "Conflict")
    stub(@response_already_exists).body { @bucket_already_exists_body }
    @bucket_already_exists_body = <<-EOAlreadyExists
    <?xml version="1.0" encoding="UTF-8"?>\n<Error> <Code>BucketAlreadyExists</Code> <Message>The requested bucket name is not available. The bucket namespace is shared by all users of the system. Please select a different name and try again.</Message> <BucketName>bucket</BucketName> <RequestId>4C154D32807C92BD</RequestId> <HostId>/xyHQgXcUXTZQhoO+NUBzbaxbFrIhKlyuaRHFnmcId0bMePvY9Zwg+dyk2LYE4g5</HostId> </Error>
    EOAlreadyExists

    @objects_list_empty = []
    @objects_list = [
      S3::Object.new(@bucket, "obj1"),
      S3::Object.new(@bucket, "obj2")
    ]

    @response_objects_list_empty = Net::HTTPOK.new("1.1", "200", "OK")
    stub(@response_objects_list_empty).body { @response_objects_list_empty_body }
    @response_objects_list_empty_body = <<-EOEmpty
    <?xml version="1.0" encoding="UTF-8"?>\n<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"> <Name>bucket</Name> <Prefix></Prefix> <Marker></Marker> <MaxKeys>1000</MaxKeys> <IsTruncated>false</IsTruncated> </ListBucketResult>
    EOEmpty

    @response_objects_list = Net::HTTPOK.new("1.1", "200", "OK")
    stub(@response_objects_list).body { @response_objects_list_body }
    @response_objects_list_body = <<-EOObjects
    <?xml version="1.0" encoding="UTF-8"?>\n<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/"> <Name>bucket</Name> <Prefix></Prefix> <Marker></Marker> <MaxKeys>1000</MaxKeys> <IsTruncated>false</IsTruncated> <Contents> <Key>obj1</Key> <LastModified>2009-07-03T10:17:33.000Z</LastModified> <ETag>&quot;99519cdf14c255e580e1b7bca85a458c&quot;</ETag> <Size>1729</Size> <Owner> <ID>df864aeb6f42be43f1d9e60aaabe3f15e245b035a4b79d1cfe36c4deaec67205</ID> <DisplayName>owner</DisplayName> </Owner> <StorageClass>STANDARD</StorageClass> </Contents> <Contents> <Key>obj2</Key> <LastModified>2009-07-03T11:17:33.000Z</LastModified> <ETag>&quot;99519cdf14c255e586e1b12bca85a458c&quot;</ETag> <Size>179</Size> <Owner> <ID>df864aeb6f42be43f1d9e60aaabe3f17e247b037a4b79d1cfe36c4deaec67205</ID> <DisplayName>owner</DisplayName> </Owner> <StorageClass>STANDARD</StorageClass> </Contents> </ListBucketResult>
    EOObjects
  end

  def test_name_valid
    assert_raise ArgumentError do S3::Bucket.new(nil, "") end # should not be valid with empty name
    assert_raise ArgumentError do S3::Bucket.new(nil, "10.0.0.1") end # should not be valid with IP as name
    assert_raise ArgumentError do S3::Bucket.new(nil, "as") end # should not be valid with name shorter than 3 characters
    assert_raise ArgumentError do S3::Bucket.new(nil, "a"*256) end # should not be valid with name longer than 255 characters
    assert_raise ArgumentError do S3::Bucket.new(nil, ".asdf") end # should not allow special characters as first character
    assert_raise ArgumentError do S3::Bucket.new(nil, "-asdf") end # should not allow special characters as first character
    assert_raise ArgumentError do S3::Bucket.new(nil, "_asdf") end # should not allow special characters as first character

    assert_nothing_raised do
      S3::Bucket.new(nil, "a-a-")
      S3::Bucket.new(nil, "a.a.")
      S3::Bucket.new(nil, "a_a_")
    end
  end

  def test_path_prefix
    expected = ""
    actual = @bucket_vhost.path_prefix
    assert_equal expected, actual

    expected = "data_bucket/"
    actual = @bucket_path.path_prefix
    assert_equal expected, actual
  end

  def test_host
    expected = "data-bucket.s3.amazonaws.com"
    actual = @bucket_vhost.host
    assert_equal expected, actual

    expected = "s3.amazonaws.com"
    actual = @bucket_path.host
    assert_equal expected, actual
  end

  def test_vhost
    assert @bucket_vhost.vhost?
    assert ! @bucket_path.vhost?
  end

  def test_exists
    mock(@bucket).retrieve { @bucket_vhost }
    assert @bucket.exists?

    mock(@bucket).retrieve { raise S3::Error::NoSuchBucket.new(nil, nil) }
    assert ! @bucket.exists?
  end

  def test_location_and_parse_location
    mock(@bucket).bucket_request(:get, {:params=>{:location=>nil}}) { @response_location }

    expected = @bucket_location
    actual = @bucket.location
    assert_equal expected, actual

    stub(@bucket).bucket_request(:get, {:params=>{:location=>nil}}) { flunk "should deliver from cached result" }
    actual = @bucket.location
    assert_equal expected, actual
  end

  def test_save
    mock(@bucket).bucket_request(:put, {:headers=>{}}) { }
    assert @bucket.save
    # mock ensures that bucket_request was called
  end

  def test_save_failure_owned_by_you
    mock(@bucket).bucket_request(:put, {:headers=>{}}) { raise S3::Error::BucketAlreadyOwnedByYou.new(409, @response_owned_by_you) }
    assert_raise S3::Error::BucketAlreadyOwnedByYou do
      @bucket.save
    end

    mock(@bucket).bucket_request(:put, {:headers=>{}}) { raise S3::Error::BucketAlreadyExists.new(409, @response_already_exists) }
    assert_raise S3::Error::BucketAlreadyExists do
      @bucket.save
    end
  end

  def test_objects
    mock(@bucket).fetch_objects { @objects_list_empty }
    expected = @objects_list_empty
    actual = @bucket.objects
    assert_equal expected, actual

    stub(@bucket).fetch_objects { flunk "should load objects from cache" }
    actual = @bucket.objects
    assert_equal expected, actual

    stub(@bucket).fetch_objects { @objects_list }
    # ugly hack
    expected = @objects_list
    actual = @bucket.objects(true).map { |obj| obj }
    assert_equal expected, actual
  end

  def test_fetch_objects_and_parse_objects
    mock(@bucket).bucket_request(:get, :test=>true) { @response_objects_list_empty }
    expected = @objects_list_empty
    actual = @bucket.objects(true, :test=>true).map { |obj| obj }
    assert_equal expected, actual

    mock(@bucket).bucket_request(:get, :test=>true) { @response_objects_list }
    expected = @objects_list
    actual = @bucket.objects(true, :test=>true).map { |obj| obj }
    assert_equal expected, actual
  end

  def test_destroy
    mock(@bucket).bucket_request(:delete) { }
    assert @bucket.destroy
  end
end
