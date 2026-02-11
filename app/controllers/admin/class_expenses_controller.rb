module Admin
  class ClassExpensesController < ApplicationController
    layout "admin"
    
    before_action :set_training_class
    before_action :set_class_expense, only: [:edit, :update, :destroy]
    
    def new
      @class_expense = @training_class.class_expenses.build
    end
    
    def create
      @class_expense = @training_class.class_expenses.build(class_expense_params)
      
      if @class_expense.save
        redirect_to admin_training_class_path(@training_class, tab: "finance"), 
                    notice: "เพิ่มรายการค่าใช้จ่ายสำเร็จ"
      else
        render :new, status: :unprocessable_entity
      end
    end
    
    def edit
    end
    
    def update
      if @class_expense.update(class_expense_params)
        redirect_to admin_training_class_path(@training_class, tab: "finance"), 
                    notice: "อัปเดตรายการค่าใช้จ่ายสำเร็จ"
      else
        render :edit, status: :unprocessable_entity
      end
    end
    
    def destroy
      @class_expense.destroy
      redirect_to admin_training_class_path(@training_class, tab: "finance"), 
                  notice: "ลบรายการค่าใช้จ่ายสำเร็จ"
    end
    
    private
    
    def set_training_class
      @training_class = TrainingClass.find(params[:training_class_id])
    end
    
    def set_class_expense
      @class_expense = @training_class.class_expenses.find(params[:id])
    end
    
    def class_expense_params
      params.require(:class_expense).permit(:description, :amount, :category)
    end
  end
end
