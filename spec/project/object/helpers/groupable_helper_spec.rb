require File.expand_path('../../../../spec_helper', __FILE__)

module ProjectSpecs
  describe Xcodeproj::Project::Object::GroupableHelper do

    before do
      @sut = GroupableHelper
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do

      before do
        @group = @project.new_group('Parent')
      end

      it "returns the parent" do
        @sut.parent(@group).should == @project.main_group
      end

      it "returns the parents of the object" do
        child = @group.new_group('Child')
        @sut.parents(child).should == [@project.main_group, @group]
      end

      it "raises if there is not a single identifiable parent" do
        new_group = @project.new_group('Child')
        new_group.add_referrer(@project.main_group)
        should.raise do
          @sut.parent(new_group)
        end.message.should.match /multiple parents/
      end

      it "returns the representation of the group hierarchy" do
        child = @group.new_group('Child')
        @sut.hierarchy_path(child).should == "/Parent/Child"
      end

    end

    #-------------------------------------------------------------------------#

    describe "::main_group" do

      it "returns that an object is the main group" do
        @sut.main_group?(@project.main_group).should.be.true
      end

      it "returns that an object is not the main group" do
        @sut.main_group?(@project.new_group('Classes')).should.be.false
      end

    end

    #-------------------------------------------------------------------------#

    describe "::move" do

      before do
        @group = @project.new_group('Parent')
      end

      it "can move an object from a group to another" do
        new_parent = @project.new_group('New Parent')
        @sut.move(@group, new_parent)
        @group.parent.should == new_parent
        @group.referrers.count.should == 1
      end

      it "raise if there there is an attempt to move a nil object" do
        should.raise do
          @sut.move(nil, @group)
        end.message.should.match /Attempt to move nil object/
      end

      it "raise if there there is an attempt to move to a nil parent" do
        should.raise do
          @sut.move(@group, nil)
        end.message.should.match /Attempt to move .* to nil parent/
      end

      it "raise if there there is an attempt to move an object to one of its children" do
        child = @group.new_group('Child')
        should.raise do
          @sut.move(@group, child)
        end.message.should.match /Attempt to move .* to a child object/
      end

      it "raise if there there is an attempt to move an object to itself" do
        should.raise do
          @sut.move(@group, @group)
        end.message.should.match /Attempt to move .* to itself/
      end

    end

    #-------------------------------------------------------------------------#

    describe "::real_path" do

      before do
        @group = @project.new_group('Parent')
      end

      it "returns the real path of an object" do
        @group.source_tree = '<group>'
        @group.path = 'Classes'
        @sut.real_path(@group).should == Pathname.new('/project_dir/Classes')
      end

    end

    #-------------------------------------------------------------------------#

    describe '::source_tree_real_path' do

      before do
        @group = @project.new_group('Parent')
      end

      it "returns a nil source tree for absolute paths" do
        @group.source_tree = '<absolute>'
        @sut.source_tree_real_path(@group).should.be.nil
      end

      it "returns the source tree of a path relative to main group" do
        @group.source_tree = '<group>'
        @sut.source_tree_real_path(@group).should == Pathname.new('/project_dir')
      end

      it "returns the source tree of a path relative to a group" do
        @group.source_tree = '<absolute>'
        @group.path = '/parent_group_path'
        children = @group.new_group('child')
        children.source_tree = '<group>'
        children.path = 'dir'
        @sut.source_tree_real_path(children).should == Pathname.new('/parent_group_path')
      end

      it "returns the source tree of a path relative to the project root" do
        @group.source_tree = 'SOURCE_ROOT'
        @sut.source_tree_real_path(@group).should == Pathname.new('/project_dir')
      end

      it "raises if unable to resolve the source tree" do
        should.raise do
          @group.source_tree = '<unknown>'
          @sut.source_tree_real_path(@group).should == Pathname.new('/project_dir')
        end.message.should.match /Unable to compute the source tree/
      end
    end

    #-------------------------------------------------------------------------#

    describe '::set_path_with_source_tree' do

      before do
        @group = @project.new_group('Parent')
      end

      it "sets an absolute path" do
        @sut.set_path_with_source_tree(@group, '/Files', :absolute)
        @group.source_tree.should == '<absolute>'
        @group.path.should == '/Files'
      end

      it "raises if a relative path is provided for an absolute source tree" do
        should.raise do
        @sut.set_path_with_source_tree(@group, 'Files', :absolute)
        end.message.should.match /Attempt to set a relative path/
      end

      it "sets a path relative to the group" do
        new_group = @group.new_group('Classes')
        @group.source_tree = '<group>'
        @group.path = 'Parent'
        @sut.set_path_with_source_tree(new_group, '/project_dir/Parent/Classes', :group)
        new_group.source_tree.should == '<group>'
        new_group.path.should == 'Classes'
      end

      it "sets a path relative to the project" do
        new_group = @group.new_group('Classes')
        @group.source_tree = '<group>'
        @group.path = 'Parent'
        @sut.set_path_with_source_tree(new_group, '/project_dir/Parent/Classes', :project)
        new_group.source_tree.should == 'SOURCE_ROOT'
        new_group.path.should == 'Parent/Classes'
      end

      it "sets a path relative to the products dir" do
        @sut.set_path_with_source_tree(@group, 'Class.m', :built_products)
        @group.source_tree.should == 'BUILT_PRODUCTS_DIR'
        @group.path.should == 'Class.m'
      end

      it "sets a path relative to the developer dir" do
        @sut.set_path_with_source_tree(@group, 'Class.m', :developer_dir)
        @group.source_tree.should == 'DEVELOPER_DIR'
        @group.path.should == 'Class.m'
      end

      it "sets a path relative to the sdk root" do
        @sut.set_path_with_source_tree(@group, 'Class.m', :sdk_root)
        @group.source_tree.should == 'SDKROOT'
        @group.path.should == 'Class.m'
      end

      it "doesn't convert to relative a path if the both the path and the source tree are not absolute or relative" do
        new_group = @group.new_group('Classes')
        @group.source_tree = '<group>'
        @group.path = 'Parent'
        @sut.set_path_with_source_tree(new_group, 'project_dir/Parent/Classes', :group)
        new_group.source_tree.should == '<group>'
        new_group.path.should == 'project_dir/Parent/Classes'
      end

      it "raises if an unsupported source key is provided" do
        should.raise do
          @sut.set_path_with_source_tree(@group, 'Files', :root_of_the_internets)
        end.message.should.match /Unrecognized source tree option/
      end

      it "raises if a nil source key is provided" do
        should.raise do
          @sut.set_path_with_source_tree(@group, 'Files', nil)
        end.message.should.match /Unrecognized source tree option/
      end
    end

    #-------------------------------------------------------------------------#

    describe '::check_parents_integrity' do

      before do
        @group = @project.new_group('Parent')
      end

      it "raises if there is not a suitable parent" do
        @group.remove_referrer(@project.main_group)
        should.raise do
          @sut.send(:check_parents_integrity, @group)
        end.message.should.match /no parent/
      end

      it "doesn't raise for objects referenced by the project which have single identifiable parent" do
        should.not.raise do
          @sut.send(:check_parents_integrity, @project.products_group)
        end
      end

      it "raises if there are multiple parents" do
        new_group = @project.new_group('Child')
        new_group.add_referrer(@project.main_group)
        should.raise do
          @sut.send(:check_parents_integrity, new_group)
        end.message.should.match /multiple parents/
      end

    end

    #-------------------------------------------------------------------------#

  end
end
