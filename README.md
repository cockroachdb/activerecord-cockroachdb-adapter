# ActiveRecord CockroachDB Adapter

CockroachDB adapter for ActiveRecord. This is a lightweight extension
of the PostgreSQL adapter that establishes compatibility with [CockroachDB](https://github.com/cockroachdb/cockroach).

## Installation

Add this line to your project's Gemfile:

```ruby
gem 'activerecord-cockroachdb-adapter', '~> 7.2.0'
```

If you're using Rails 7.0, use the `7.0.x` versions of this gem.

If you're using Rails 7.1, use the `7.1.x` versions of this gem.

If you're using Rails 7.2, use the `7.2.x` versions of this gem.
The minimal CockroachDB version required is 23.1.12 for this version.

In `database.yml`, use the following adapter setting:

```
development:
  adapter: cockroachdb
  port: 26257
  host: <hostname>
  user: <username>
```

## Configuration

In addition to the standard adapter settings, CockroachDB also supports the following:

- `use_follower_reads_for_type_introspection`: Use follower reads on queries to the `pg_type` catalog when set to `true`. This helps to speed up initialization by reading historical data, but may not find recently created user-defined types.
- `disable_cockroachdb_telemetry`: Determines if a telemetry call is made to the database when the connection pool is initialized. Setting this to `true` will prevent the call from being made.

## Working with Spatial Data

The adapter uses [RGeo](https://github.com/rgeo/rgeo) and [RGeo-ActiveRecord](https://github.com/rgeo/rgeo-activerecord) to represent geometric and geographic data as Ruby objects and easily interface them with the adapter. The following is a brief introduction to RGeo and tips to help setup your spatial application. More documentation about RGeo can be found in the [YARD Docs](https://rubydoc.info/github/rgeo/rgeo) and [wiki](https://github.com/rgeo/rgeo/wiki).

### Installing RGeo

RGeo can be installed with the following command:

```sh
gem install rgeo
```

The best way to use RGeo is with GEOS support. If you have a version of libgeos installed, you can check that it was properly linked with RGeo by running the following commands:

```rb
require 'rgeo'

RGeo::Geos.supported?
#=> true
```

If this is `false`, you may need to specify the GEOS directory while installing. Here's an example linking it to the CockroachDB GEOS binary.

```sh
gem install rgeo -- --with-geos-dir=/path/to/cockroach/lib/
```

### Working with RGeo

RGeo uses [factories](https://en.wikipedia.org/wiki/Factory_(object-oriented_programming)) to create geometry objects and define their properties. Different factories define their own implementations for standard methods. For instance, the `RGeo::Geographic.spherical_factory` accepts latitudes and longitues as its coordinates and does computations on a spherical surface, while `RGeo::Cartesian.factory` implements geometry objects on a plane.

The factory (or factories) you choose to use will depend on the requirements of your application and what you need to do with the geometries they produce. For example, if you are working with points or other simple geometries across long distances and need precise results, the spherical factory is a good choice. If you're working with polygons or multipolygons and analyzing complex relationships between them (`intersects?`, `difference`, etc.), then using a cartesian factory backed by GEOS is a much better option.

Once you've selected a factory, you need to create objects. RGeo supports geometry creation through standard constructors (`point`, `line_string`, `polygon`, etc.) or by WKT and WKB.

```rb
require 'rgeo'
factory = RGeo::Cartesian.factory(srid: 3857)

# Create a line_string from points
pt1 = factory.point(0,0)
pt2 = factory.point(1,1)
pt3 = factory.point(2,2)
line_string = factory.line_string([pt1,pt2,pt3])

p line_string.length
#=> 2.8284271247461903

# check line_string equality
line_string2 = factory.parse_wkt("LINESTRING (0 0, 1 1, 2 2)")
p line_string == line_string2
#=> true

# create polygon and test intersection with line_string
pt4 = factory.point(0,2)
outer_ring = factory.linear_ring([pt1,pt2,pt3,pt4,pt1])
poly = factory.polygon(outer_ring)

p line_string.intersects? poly
#=> true
```
### Creating Spatial Tables

To store spatial data, you must create a column with a spatial type. PostGIS
provides a variety of spatial types, including point, linestring, polygon, and
different kinds of collections. These types are defined in a standard produced
by the Open Geospatial Consortium. You can specify options indicating the coordinate system and number of coordinates for the values you are storing.

The adapter extends ActiveRecord's migration syntax to
support these spatial types. The following example creates five spatial
columns in a table:

```rb
create_table :my_spatial_table do |t|
  t.column :shape1, :geometry
  t.geometry :shape2
  t.line_string :path, srid: 3857
  t.st_point :lonlat, geographic: true
  t.st_point :lonlatheight, geographic: true, has_z: true
end
```

The first column, "shape1", is created with type "geometry". This is a general
"base class" for spatial types; the column declares that it can contain values
of _any_ spatial type.

The second column, "shape2", uses a shorthand syntax for the same type as the shape1 column.
You can create a column either by invoking `column` or invoking the name of the type directly.

The third column, "path", has a specific geometric type, `line_string`. It
also specifies an SRID (spatial reference ID) that indicates which coordinate
system it expects the data to be in. The column now has a "constraint" on it;
it will accept only LineString data, and only data whose SRID is 3857.

The fourth column, "lonlat", has the `st_point` type, and accepts only Point
data. Furthermore, it declares the column as "geographic", which means it
accepts longitude/latitude data, and performs calculations such as distances
using a spheroidal domain.

The fifth column, "lonlatheight", is a geographic (longitude/latitude) point
that also includes a third "z" coordinate that can be used to store height
information.

The following are the data types understood by PostGIS and exposed by
the adapter:

- `:geometry` -- Any geometric type
- `:st_point` -- Point data
- `:line_string` -- LineString data
- `:st_polygon` -- Polygon data
- `:geometry_collection` -- Any collection type
- `:multi_point` -- A collection of Points
- `:multi_line_string` -- A collection of LineStrings
- `:multi_polygon` -- A collection of Polygons

Following are the options understood by the adapter:

- `:geographic` -- If set to true, create a PostGIS geography column for
  longitude/latitude data over a spheroidal domain; otherwise create a
  geometry column in a flat coordinate system. Default is false. Also
  implies :srid set to 4326.
- `:srid` -- Set a SRID constraint for the column. Default is 4326 for a
  geography column, or 0 for a geometry column. Note that PostGIS currently
  (as of version 2.0) requires geography columns to have SRID 4326, so this
  constraint is of limited use for geography columns.
- `:has_z` -- Specify that objects in this column include a Z coordinate.
  Default is false.
- `:has_m` -- Specify that objects in this column include an M coordinate.
  Default is false.

To create a PostGIS spatial index, add `using: :gist` to your index:

```rb
add_index :my_table, :lonlat, using: :gist

# or

change_table :my_table do |t|
  t.index :lonlat, using: :gist
end
```
### Configuring ActiveRecord

ActiveRecord's usefulness stems from the way it automatically configures
classes based on the database structure and schema. If a column in the
database has an integer type, ActiveRecord automatically casts the data to a
Ruby Integer. In the same way, the adapter automatically
casts spatial data to a corresponding RGeo data type.

RGeo offers more flexibility in its type system than can be
interpreted solely from analyzing the database column. For example, you can
configure RGeo objects to exhibit certain behaviors related to their
serialization, validation, coordinate system, or computation. These settings
are embodied in the RGeo factory associated with the object.

You can configure the adapter to use a particular factory (i.e. a
particular combination of settings) for data associated with each type in
the database.

Here's an example using a Geos default factory:

```ruby
RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  # By default, use the GEOS implementation for spatial columns.
  config.default = RGeo::Geos.factory_generator

  # But use a geographic implementation for point columns.
  config.register(RGeo::Geographic.spherical_factory(srid: 4326), geo_type: "point")
end
```

The default spatial factory for geographic columns is `RGeo::Geographic.spherical_factory`.
The default spatial factory for cartesian columns is `RGeo::Cartesian.preferred_factory`.
You do not need to configure the `SpatialFactoryStore` if these defaults are ok.

More information about configuration options for the `SpatialFactoryStore` can be found in the [rgeo-activerecord](https://github.com/rgeo/rgeo-activerecord#spatial-factories-for-columns) docs.

### Reading and Writing Spatial Columns

When you access a spatial attribute on your ActiveRecord model, it is given to
you as an RGeo geometry object (or nil, for attributes that allow null
values). You can then call the RGeo api on the object. For example, consider
the MySpatialTable class we worked with above:

```rb
record = MySpatialTable.find(1)
point = record.lonlat                  # Returns an RGeo::Feature::Point
p point.x                              # displays the x coordinate
p point.geometry_type.type_name        # displays "Point"
```

The RGeo factory for the value is determined by how you configured the
ActiveRecord class, as described above. In this case, we explicitly set a
spherical factory for the `:lonlat` column:

```rb
factory = point.factory                # returns a spherical factory
```

You can set a spatial attribute by providing an RGeo geometry object, or by
providing the WKT string representation of the geometry. If a string is
provided, the adapter will attempt to parse it as WKT and
set the value accordingly.

```rb
record.lonlat = 'POINT(-122 47)'  # sets the value to the given point
```

If the WKT parsing fails, the value currently will be silently set to nil. In
the future, however, this will raise an exception.

```rb
record.lonlat = 'POINT(x)'         # sets the value to nil
```

If you set the value to an RGeo object, the factory needs to match the factory
for the attribute. If the factories do not match, the adapter
will attempt to cast the value to the correct factory.

```rb
p2 = factory.point(-122, 47)       # p2 is a point in a spherical factory
record.lonlat = p2                 # sets the value to the given point
record.shape1 = p2                 # shape1 uses a flat geos factory, so it
                                   # will cast p2 into that coordinate system
                                   # before setting the value
record.save
```

If you attempt to set the value to the wrong type, such as setting a linestring attribute to a point value, you will get an exception from the database when you attempt to save the record.

```rb
record.path = p2      # This will appear to work, but...
record.save           # This will raise an exception from the database
```

### Spatial Queries

You can create simple queries based on representational equality in the same
way you would on a scalar column:

```ruby
record2 = MySpatialTable.where(:lonlat => factory.point(-122, 47)).first
```

You can also use WKT:

```ruby
record3 = MySpatialTable.where(:lonlat => 'POINT(-122 47)').first
```

Note that these queries use representational equality, meaning they return
records where the lonlat value matches the given value exactly. A 0.00001
degree difference would not match, nor would a different representation of the
same geometry (like a multi_point with a single element). Equality queries
aren't generally all that useful in real world applications. Typically, if you
want to perform a spatial query, you'll look for, say, all the points within a
given area. For those queries, you'll need to use the standard spatial SQL
functions provided by PostGIS.

To perform more advanced spatial queries, you can use the extended Arel interface included in the adapter. The functions accept WKT strings or RGeo features.

```rb
point = RGeo::Geos.factory(srid: 0).point(1,1)

# Example Building model where geom is a column of polygons.
buildings = Building.arel_table
containing_buiildings = Building.where(buildings[:geom].st_contains(point))
```

See the [rgeo-activerecord YARD Docs](https://rubydoc.info/github/rgeo/rgeo-activerecord/RGeo/ActiveRecord/SpatialExpressions) for a list of available PostGIS functions.

### Validation Issues

If you see an `RGeo::Error::InvalidGeometry (LinearRing failed ring test)` message while loading data or creating geometries, this means that the geometry you are trying to instantiate is not topologically valid. This is usually due to self-intersections in the geometry. The default behavior of RGeo factories is to raise this error when an invalid geometry is being instansiated, but this can be ignored by setting the `uses_lenient_assertions` flag to `true` when creating your factory.

```rb
regular_fac = RGeo::Geographic.spherical_factory
modified_fac = RGeo::Geographic.spherical_factory(uses_lenient_assertions: true)

wkt = "POLYGON (0 0, 1 1, 0 1, 1 0, 0 0)" # closed ring with self intersection

regular_fac.parse_wkt(wkt)
#=> RGeo::Error::InvalidGeometry (LinearRing failed ring test)

p modified_fac.parse_wkt(wkt)
#=>  #<RGeo::Geographic::SphericalPolygonImpl>
```

Be careful when performing calculations on potentially invalid geometries, as the results might be nonsensical. For example, the area returned of an hourglass made of 2 equivalent triangles with a self-intersection in the middle is 0.

Note that when using the `spherical_factory`, there is a chance that valid geometries will be interpreted as invalid due to floating point issues with small geometries.

## Modifying the adapter?

See [CONTRIBUTING.md](/CONTRIBUTING.md) for more details on setting up
the environment and making modifications.
